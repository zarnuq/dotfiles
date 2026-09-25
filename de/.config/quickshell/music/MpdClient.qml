pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The MPD client: the protocol itself, spoken over a socket from QML.
//
// Why not `mpc`: every query would be a fork, and the interesting ones are not
// one-shot — a music browser wants to know the instant the song, the queue or a
// toggle changes. That is what MPD's `idle` gives us for free, and what the old
// Mpd.qml card could not have (MPRIS publishes the current track and nothing
// else: no queue, no library, no playlists).
//
// **Transport.** MPD 0.24 opens $XDG_RUNTIME_DIR/mpd/socket on its own, with no
// `bind_to_address` line in mpd.conf. That matters because Quickshell's `Socket`
// is a QLocalSocket — unix only, no TCP — so the port 6600 that rmpc uses is not
// reachable from here at all. The socket being a 0.24 default is the whole
// reason this needs no mpd.conf change; on an older MPD it would.
//
// **Two connections, deliberately.** `idle` blocks its connection until
// something changes, so a client that idles on the only connection it has can
// never ask a question. Every real MPD client keeps a second one. Here `idleSock`
// parks in `idle` and does nothing but report which subsystems changed, and
// `cmdSock` carries every command. The alternative (one socket, `noidle` before
// each command) races: the noidle and the change can cross.
//
// **The response format.** MPD answers `key: value` lines terminated by `OK` or
// `ACK [..] {..} message`. Commands are strictly FIFO, so one in flight at a
// time with a callback queue behind it is enough — no request ids, no matching.
Singleton {
    id: root

    // MPD 0.24's default socket. MPD_HOST wins when it names a socket path, so
    // a box that does set bind_to_address still works.
    readonly property string socketPath: {
        var h = Quickshell.env("MPD_HOST") || "";
        if (h.indexOf("/") === 0 || h.indexOf("@") === 0) return h.replace(/^@/, "");
        return (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/mpd/socket";
    }

    readonly property bool connected: cmdSock.connected && root._greeted

    // ── Live state ───────────────────────────────────────────────────────
    // Assigned as whole objects, never mutated: QML notifies on assignment only.
    property var status: ({})
    property var song: ({})
    property var queue: []
    property int queueVersion: -1

    readonly property string playState: root.status.state || "stop"
    readonly property bool playing: root.playState === "play"
    readonly property bool stopped: root.playState === "stop"

    // What we asked for, until MPD's own status agrees. Its `volume` only comes
    // back through the idle loop (`mixer` -> `status`), so the readout trailed
    // the keypress by a round trip AND a held key computed every step off a
    // number several presses old, losing most of them. Same shape as the seek
    // guard below, for the same reason.
    property int _volWanted: -1
    readonly property int volume: root._volWanted >= 0 ? root._volWanted
                                  : parseInt(root.status.volume || "0")
    readonly property bool repeatOn: root.status.repeat === "1"
    readonly property bool randomOn: root.status.random === "1"
    // consume and single are tri-state in MPD 0.24: 0, 1 or "oneshot".
    readonly property string consumeMode: root.status.consume || "0"
    readonly property string singleMode: root.status.single || "0"

    readonly property int songPos: root.status.song !== undefined ? parseInt(root.status.song) : -1
    readonly property int songId: root.status.songid !== undefined ? parseInt(root.status.songid) : -1
    readonly property int queueLength: parseInt(root.status.playlistlength || "0")
    readonly property real duration: parseFloat(root.status.duration || "0")

    // MPD reports `elapsed` only when asked, so a progress bar bound straight to
    // it would step once per change rather than once per second. Extrapolate
    // from the last reading instead: no polling, and re-anchored by every status
    // refresh (which `idle player` delivers on each song change anyway).
    property real _elapsedBase: 0
    property double _elapsedAt: 0
    property int _tick: 0
    readonly property real elapsed: {
        root._tick;                                   // re-evaluate each second
        if (!root.playing) return root._elapsedBase;
        return root._elapsedBase + (Date.now() - root._elapsedAt) / 1000;
    }
    Timer { interval: 1000; running: root.playing; repeat: true; onTriggered: root._tick++ }

    signal changed(string subsystem)

    // ── Commands ─────────────────────────────────────────────────────────

    /// Quote an argument the way the MPD protocol wants it.
    function q(v) { return '"' + String(v).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'; }

    property var _jobs: []        // [{ cmd, cb }] — FIFO, one in flight
    property bool _busy: false
    property var _lines: []
    property bool _greeted: false

    /// Send `text`; `cb(lines, err)` gets the raw response lines, or err set to
    /// the ACK line when MPD refused it.
    function send(text, cb) {
        root._jobs.push({ cmd: text, cb: cb || null });
        root._pump();
    }

    /// Several commands as one request. MPD answers a command list with a
    /// single OK, so this is also how a multi-row action stays atomic: the
    /// whole list applies, or the first failure aborts the rest of it.
    function sendList(cmds, cb) {
        if (cmds.length === 0) { if (cb) cb([], null); return; }
        if (cmds.length === 1) { root.send(cmds[0], cb); return; }
        root.send("command_list_begin\n" + cmds.join("\n") + "\ncommand_list_end", cb);
    }

    function _pump() {
        if (root._busy || !cmdSock.connected || root._jobs.length === 0) return;
        root._busy = true;
        cmdSock.write(root._jobs[0].cmd + "\n");
        cmdSock.flush();
    }

    function _onCmdLine(line) {
        // The greeting is not a response — it arrives unprompted on connect.
        if (line.indexOf("OK MPD ") === 0) {
            root._greeted = true;
            root.refreshAll();
            return;
        }
        var ack = line.indexOf("ACK ") === 0;
        if (line !== "OK" && !ack) {
            root._lines.push(line);
            return;
        }
        var job = root._jobs.shift();
        var lines = root._lines;
        root._lines = [];
        root._busy = false;
        // finally: a callback that throws — a pane writing to a view the window
        // just destroyed is the easy way in — would otherwise skip the pump and
        // strand every command queued behind it, with nothing to restart it.
        try {
            if (job && job.cb) job.cb(lines, ack ? line : null);
        } finally {
            root._pump();
        }
    }

    // ── Response parsing ─────────────────────────────────────────────────

    /// Flat `key: value` lines (status, currentsong) into one object.
    function parseKV(lines) {
        var o = {};
        for (var i = 0; i < lines.length; i++) {
            var c = lines[i].indexOf(": ");
            if (c > 0) o[lines[i].substring(0, c)] = lines[i].substring(c + 2);
        }
        return o;
    }

    /// Repeating records (a song list, a directory listing) into an array.
    // MPD marks no record boundary of its own — a new record simply begins at a
    // known leading key, which is why the caller names them. `_type` records
    // which one started this entry, so lsinfo's mixed file/directory/playlist
    // rows stay distinguishable without re-testing their keys later.
    function parseRecords(lines, startKeys) {
        var out = [];
        var cur = null;
        for (var i = 0; i < lines.length; i++) {
            var c = lines[i].indexOf(": ");
            if (c <= 0) continue;
            var k = lines[i].substring(0, c);
            var v = lines[i].substring(c + 2);
            if (startKeys.indexOf(k) >= 0) {
                if (cur) out.push(cur);
                cur = { _type: k };
            }
            if (cur) cur[k] = v;
        }
        if (cur) out.push(cur);
        return out;
    }

    /// Artist — Title for a song record, falling back to its path. A file with
    /// no tags at all is common enough in a library this size to be worth it.
    function songTitle(s) {
        if (!s) return "";
        if (s.Title) return s.Title;
        var f = s.file || "";
        return f.substring(f.lastIndexOf("/") + 1);
    }

    function fmtTime(sec) {
        if (!sec || sec < 0 || isNaN(sec)) return "0:00";
        var t = Math.floor(sec);
        var h = Math.floor(t / 3600);
        var m = Math.floor((t % 3600) / 60);
        var s = t % 60;
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
                     : m + ":" + String(s).padStart(2, "0");
    }

    // ── Refreshers ───────────────────────────────────────────────────────

    /// Apply a `status` reply. Both callers go through here so the seek guard
    /// below can't be implemented in one of them and forgotten in the other.
    function _applyStatus(lines) {
        var wasId = root.songId;
        root.status = root.parseKV(lines);
        // MPD has caught up with the pending volume: hand the readout back.
        if (root._volWanted >= 0 && parseInt(root.status.volume || "-1") === root._volWanted) {
            root._volWanted = -1;
            volRelease.stop();
        }
        // Any status re-anchors the clock, so the dedupe below must not survive
        // it: otherwise seeking back to a position already used in this track
        // (trivial at either clamp, or by clicking the same spot on the bar)
        // sent nothing while the local clock jumped anyway, and no `player`
        // change ever arrived to correct it.
        root._lastSeekSent = -1;
        // While a seek is being held down, MPD's `elapsed` describes a position
        // several repeats old by the time it arrives, and letting it win makes
        // the progress bar jump backwards between presses. The local clock is
        // authoritative until the seeking has stopped.
        if (Date.now() >= root._seekGuardUntil) {
            root._elapsedBase = parseFloat(root.status.elapsed || "0");
            root._elapsedAt = Date.now();
        }
    }

    function refreshStatus() {
        root.send("status", function (lines) { root._applyStatus(lines); });
    }

    function refreshSong() {
        root.send("currentsong", function (lines) { root.song = root.parseKV(lines); });
    }

    // The queue is the one expensive thing this client holds: 6k songs is
    // ~110k protocol lines parsed into 6k objects. Nothing needs it while the
    // window is shut, so it is refcounted — released on close, refetched on
    // open (~250 ms, once). The idle loop keeps running either way; it just
    // stops syncing a queue nobody is reading.
    property int _queueHolders: 0
    readonly property bool queueRetained: root._queueHolders > 0

    function retainQueue() {
        root._queueHolders++;
        if (root._queueHolders === 1 && root.connected) root.refreshQueue();
    }

    function releaseQueue() {
        root._queueHolders = Math.max(0, root._queueHolders - 1);
        if (root._queueHolders > 0) return;
        root.queue = [];
        root.queueVersion = -1;
        root.queueWasBulk = true;     // the refetch on reopen is not an "add"
        // Dropping the reference is not the same as reclaiming it: the JS heap
        // is collected lazily, so RSS stayed put after closing the window and
        // only fell on some later unrelated collection. Measured on a 6k queue:
        // 309 MB -> 281 MB the moment this runs. The window has just closed, so
        // a full collection here costs a pause nobody is looking at.
        Qt.callLater(gc);
    }

    /// True while the queue arrived as a first read rather than an edit. The
    /// banner uses it to stay quiet about the initial several-thousand-song
    /// load. It is NOT "did we refetch": syncQueue falls back to a refetch on
    /// anything it cannot express incrementally — an add of more than 64 new
    /// songs, or any add at all onto an empty queue — and those are real adds
    /// that must still be announced. `Shift+A` on the library is both at once.
    property bool queueWasBulk: false

    // The one expensive call: 4311 songs is 78k lines / 1.8 MB / ~180 ms on this
    // box. So it is never polled — only the first open and an actual `playlist`
    // change reach it, and `plchangesposid` below covers the common small edits.
    /// `bulk` false says this refetch is standing in for an edit idle already
    /// told us about, so the size of it is the user's doing, not a first read.
    function refreshQueue(bulk) {
        root.send("playlistinfo", function (lines) {
            root.queueWasBulk = bulk !== false;
            root.queue = root.parseRecords(lines, ["file"]);
            root.queueVersion = parseInt(root.status.playlist || "-1");
        });
    }

    // A queue edit bumps MPD's playlist version; plchanges returns only entries
    // at or after the version given, which for the usual one-song add is a
    // handful of lines instead of the full 1.8 MB. Anything that moves more than
    // it would cost to refetch falls back to the full list.
    function syncQueue() {
        var from = root.queueVersion;
        var newVersion = parseInt(root.status.playlist || "-1");
        if (from < 0 || root.queue.length === 0) { root.refreshQueue(false); return; }

        // plchangesposid, NOT plchanges. An edit anywhere renumbers every song
        // after it, and `plchanges` answers with FULL records for each one —
        // measured 2.67 MB / 250 ms for a change at position 0 on this queue,
        // exactly the refetch it is meant to avoid. The posid form answers the
        // same question as cpos/Id pairs (129 KB / 25 ms) and the metadata is
        // already here keyed by Id, so only genuinely NEW ids cost anything.
        root.send("plchangesposid " + from, function (lines, err) {
            if (err) { root.refreshQueue(false); return; }
            root.queueWasBulk = false;

            var byId = {};
            for (var i = 0; i < root.queue.length; i++) byId[root.queue[i].Id] = root.queue[i];

            var next = root.queue.slice();
            // A shrink can't be expressed as changed entries, so trim first.
            if (root.queueLength < next.length) next.length = root.queueLength;

            var pairs = root.parseRecords(lines, ["cpos"]);
            var missing = [];
            for (var j = 0; j < pairs.length; j++) {
                var pos = parseInt(pairs[j].cpos);
                if (isNaN(pos)) continue;
                var known = byId[pairs[j].Id];
                if (known) {
                    // Same song, new slot. Copy rather than mutate: the old
                    // array is still the live model until we assign.
                    if (known.Pos === String(pos)) next[pos] = known;
                    else { var moved = Object.assign({}, known); moved.Pos = String(pos); next[pos] = moved; }
                } else {
                    next[pos] = null;
                    missing.push({ pos: pos, id: pairs[j].Id });
                }
            }

            function finish() {
                // A hole means a version we never saw; only a refetch is honest.
                for (var k = 0; k < next.length; k++)
                    if (!next[k]) { root.refreshQueue(false); return; }
                root.queue = next;
                root.queueVersion = newVersion;
            }

            if (missing.length === 0) { finish(); return; }
            // Past a certain number of new songs the round trips cost more than
            // one bulk read, so stop being clever.
            if (missing.length > 64) { root.refreshQueue(false); return; }

            var cmds = [];
            for (var m = 0; m < missing.length; m++) cmds.push("playlistid " + missing[m].id);
            root.sendList(cmds, function (lines2, err2) {
                if (err2) { root.refreshQueue(false); return; }
                var songs = root.parseRecords(lines2, ["file"]);
                if (songs.length !== missing.length) { root.refreshQueue(false); return; }
                for (var s = 0; s < songs.length; s++) next[missing[s].pos] = songs[s];
                finish();
            });
        });
    }

    function refreshAll() {
        root.refreshStatus();
        root.refreshSong();
        if (root.queueRetained) root.refreshQueue();
    }

    // ── Transport / options ──────────────────────────────────────────────
    // Nothing here refreshes by hand: every one of these changes a subsystem,
    // and the idle connection reports it a moment later. Doing both would just
    // double the queries.

    function toggle()          { root.send(root.playing ? "pause 1" : (root.stopped ? "play" : "pause 0")); }
    function playId(id)        { root.send("playid " + id); }
    function stop()            { root.send("stop"); }
    function next()            { root.send("next"); }
    function previous()        { root.send("previous"); }
    // NEVER land on the end of a track. `seekcur <duration>` completes it and
    // MPD moves to the next song, so holding the seek key re-seeked to each new
    // track's end and walked the queue about a song a second — and at that rate
    // MPD 0.24.12's output thread hit an assertion in PlayChunk and died.
    //
    // The guard is several seconds rather than a token amount for two reasons:
    // landing one second from the end still ends the track a second later, so
    // the runaway continued; and seeking to the last moments of a FLAC is what
    // produced the "Decoder failed to seek" runs. Parking here leaves a real
    // gap of playback, which is both the natural end of a fast-forward and long
    // enough to notice and let go.
    readonly property real _seekTailGuard: 5.0
    function clampSeek(sec) {
        var end = Math.max(0, root.duration - root._seekTailGuard);
        return Math.max(0, Math.min(end, sec));
    }

    /// Move the LOCAL clock now and let the flush below send it. Both entry
    /// points come through here so the guard and the repaint cannot be set in
    /// one of them and forgotten in the other.
    function _seek(sec) {
        if (root.duration <= 0) return;
        root._seekPending = true;
        root._seekGuardUntil = Date.now() + root._seekGuardMs;
        root._elapsedBase = root.clampSeek(sec);
        root._elapsedAt = Date.now();
        root._tick++;                       // repaint now, not on the next second
        seekFlush.restart();
    }

    function seekTo(sec)   { root._seek(sec); }

    // Holding the seek key is reach's 50/s key repeat, so a naive one-command-
    // per-press sends fifty `seekcur`s a second. Each is a `player` change, each
    // brings a `status` back, and the bar ends up flickering between the position
    // the key asked for and whichever reply landed last — which is exactly what
    // holding Left looked like. Two fixes, both needed:
    //   - coalesce the repeats into one command per _seekFlushMs, so MPD sees a
    //     single seek of the accumulated size rather than fifty small ones;
    //   - move the local clock immediately, so the bar tracks the key rather
    //     than the round trip, and guard it from the replies still in flight.
    // A flag, not an accumulator: the flush sends an absolute position taken
    // from the local clock, so there is nothing to sum.
    property bool _seekPending: false
    property real _lastSeekSent: -1
    property double _seekGuardUntil: 0
    readonly property int _seekFlushMs: 90
    readonly property int _seekGuardMs: 500

    function seekBy(delta) { root._seek(root.elapsed + delta); }

    Timer {
        id: seekFlush
        interval: root._seekFlushMs
        onTriggered: {
            if (!root._seekPending) return;
            root._seekPending = false;
            // Absolute, not relative: by now the local clock is the thing the
            // user has been watching, and a relative seek would compound with
            // whatever MPD did with the previous batch.
            var target = root.clampSeek(root._elapsedBase);
            // Guards only against duplicates inside one burst — any arriving
            // status clears it (see _applyStatus), so a later seek to the same
            // spot is always sent.
            if (Math.abs(target - root._lastSeekSent) < 0.05) return;
            root._lastSeekSent = target;
            root.send("seekcur " + target.toFixed(2), function (lines, err) {
                if (!err) return;
                // MPD ADVANCES TO THE NEXT TRACK when a seek fails, and a
                // damaged file whose decoder cannot seek near its end fails
                // every time — so a held key walked the whole queue, a song a
                // second, until MPD's output thread died on an assertion. Stop
                // seeking and resync instead of feeding the loop.
                root._seekPending = false;
                root._lastSeekSent = -1;
                root._seekGuardUntil = 0;
                seekFlush.stop();
                root.refreshStatus();
                root.refreshSong();
            });
        }
    }
    // Coalesced like the seek: key repeat is 50/s, and one `setvol` round trip
    // per press queues them behind each other on a FIFO socket — which is the
    // audible lag, not just a slow number.
    property bool _volDirty: false

    function setVolume(v) {
        var target = Math.max(0, Math.min(100, Math.round(v)));
        if (target === root._volWanted) return;
        root._volWanted = target;
        root._volDirty = true;
        if (!volFlush.running) root._flushVolume();
    }
    function changeVolume(d)   { root.setVolume(root.volume + d); }

    function _flushVolume() {
        volRelease.stop();
        root.send("setvol " + root._volWanted);
        root._volDirty = false;
        volFlush.restart();
    }

    Timer {
        id: volFlush
        interval: 60
        onTriggered: {
            if (root._volDirty) root._flushVolume();
            else volRelease.restart();
        }
    }
    // Fallback only: normally a matching `status` releases the readout (see
    // _applyStatus). This catches a setvol MPD never honoured — no mixer, say —
    // so the number cannot sit there lying about it.
    Timer {
        id: volRelease
        interval: 1000
        onTriggered: root._volWanted = -1;
    }

    function toggleRepeat()    { root.send("repeat " + (root.repeatOn ? 0 : 1)); }
    function toggleRandom()    { root.send("random " + (root.randomOn ? 0 : 1)); }
    // rmpc cycles these through oneshot, which is MPD 0.24's third value.
    function _cycleMode(mode)  { return mode === "0" ? "1" : mode === "1" ? "oneshot" : "0"; }
    function toggleConsume()   { root.send("consume " + root._cycleMode(root.consumeMode)); }
    function toggleSingle()    { root.send("single " + root._cycleMode(root.singleMode)); }

    function clearQueue()      { root.send("clear"); }
    /// Rescan changed files. `rescan` would re-read every file regardless of
    /// mtime; this is the cheap one, and what "I just added an album" wants.
    function update()          { root.send("update"); }
    function moveSong(from, to) { root.send("move " + from + " " + to); }

    // ── Library, playlists, search ───────────────────────────────────────
    // All of these are read-on-demand: nothing here is polled or cached, since
    // MPD answers every one of them in single-digit milliseconds over a socket
    // that is already open. `cb` gets parsed records.

    /// Send `cmd` and hand `cb` its parsed records — an empty list on an ACK,
    /// so a pane never has to tell "refused" from "nothing there".
    function _read(cmd, startKeys, cb) {
        root.send(cmd, function (lines, err) {
            cb(err ? [] : root.parseRecords(lines, startKeys), err);
        });
    }

    /// One directory level. Mixed rows: `directory`, `file`, `playlist`.
    function lsinfo(uri, cb) {
        root._read("lsinfo " + root.q(uri), ["directory", "file", "playlist"], cb);
    }

    // Sorted here so no caller disagrees about the order.
    function listPlaylists(cb) {
        root._read("listplaylists", ["playlist"], function (records) {
            records.sort((a, b) => a.playlist.localeCompare(b.playlist));
            cb(records);
        });
    }

    function playlistSongs(name, cb) {
        root._read("listplaylistinfo " + root.q(name), ["file"], cb);
    }

    /// Library search. MPD matches case-insensitively and as a substring, which
    /// is what rmpc's `mode: Contains` means — the matching is server-side, so
    /// nothing like the launcher's in-process index is needed here.
    function search(tag, query, cb) {
        if (!query) { cb([], null); return; }
        root._read("search " + tag + " " + root.q(query), ["file"], cb);
    }

    // ── Queue building ───────────────────────────────────────────────────
    // A directory URI adds everything under it, which is MPD's own behaviour
    // for `add`, so "add this album" needs no recursion here.
    function addUri(uri)            { root.send("add " + root.q(uri)); }

    /// Add then play it by the Id `addid` answers with. Two round trips, not a
    /// command list — but playing by Id rather than position means nothing
    /// queued in between can shift which song that is.
    function addAndPlay(uri) {
        root.send("addid " + root.q(uri), function (lines, err) {
            if (err) return;
            var kv = root.parseKV(lines);
            if (kv.Id !== undefined) root.playId(kv.Id);
        });
    }

    function loadPlaylist(name)          { root.send("load " + root.q(name)); }
    function removePlaylist(name)        { root.send("rm " + root.q(name)); }
    function savePlaylist(name)          { root.send("save " + root.q(name)); }

    /// Append to a STORED playlist. `playlistadd` creates the playlist when it
    /// does not exist, which is what lets the picker's "new playlist" row be
    /// this same command with a typed name. A directory URI adds everything
    /// beneath it, as `add` does to the queue (checked against MPD 0.24).
    function playlistAdd(name, uris, cb) {
        var qn = root.q(name), cmds = [];
        for (var i = 0; i < uris.length; i++)
            cmds.push("playlistadd " + qn + " " + root.q(uris[i]));
        root.sendList(cmds, cb);
    }

    /// Remove one song from a stored playlist BY POSITION — the only handle
    /// MPD offers here, so the caller passes the row index it drew.
    function playlistRemoveAt(name, pos, cb) {
        root.send("playlistdelete " + root.q(name) + " " + pos, cb);
    }

    // ── Sockets ──────────────────────────────────────────────────────────

    Socket {
        id: cmdSock
        path: root.socketPath
        connected: true
        parser: SplitParser {
            splitMarker: "\n"
            onRead: line => root._onCmdLine(line)
        }
        // Drop everything in flight: the callbacks belong to a conversation
        // that no longer exists, and replaying them onto a fresh connection
        // would answer the wrong questions.
        onConnectionStateChanged: if (!connected) {
            root._greeted = false;
            root._busy = false;
            root._jobs = [];
            root._lines = [];
        }
    }

    // MPD closes a connection that has gone quiet for `connection_timeout`
    // (60s by default, and mpd.conf does not set it). cmdSock sits silent
    // between commands, so the server hung up on it roughly once a minute; the
    // retry timer at the bottom reconnected, and the greeting on the fresh
    // connection runs refreshAll() — a full refetch of the 6k queue whenever it
    // is retained, plus a reset of queueWasBulk. One cheap command well inside
    // that window keeps the connection alive instead. idleSock needs none: MPD
    // does not time out a connection parked in `idle`.
    Timer {
        interval: 30000
        repeat: true
        running: root.connected
        onTriggered: root.send("ping")
    }

    // Parked in `idle`, which answers `changed: <subsystem>` lines and then OK.
    // Re-armed immediately, so there is no window in which a change is missed.
    property var _idleChanges: []

    Socket {
        id: idleSock
        path: root.socketPath
        connected: true
        parser: SplitParser {
            splitMarker: "\n"
            onRead: line => root._onIdleLine(line)
        }
    }

    // Note on the log: a `QLocalSocket::PeerClosedError` appears once per
    // quickshell config reload and is expected — it is the *previous*
    // generation's two connections being destroyed, which MPD sees as the peer
    // hanging up. Measured: six live MPD state changes with no reload in
    // between produce none at all. Reach.qml's socket logs the same way.

    function _onIdleLine(line) {
        if (line.indexOf("OK MPD ") === 0) { root._arm(); return; }
        if (line.indexOf("changed: ") === 0) {
            root._idleChanges.push(line.substring(9));
            return;
        }
        if (line !== "OK" && line.indexOf("ACK ") !== 0) return;

        // An ACK here means MPD refused the `idle` line itself — an older server
        // rejecting one of the subsystems we ask for. Re-arming immediately
        // rewrites the command that just failed, which is an unbounded tight
        // loop: a pegged core and a flooded log for the whole session. Back off
        // and retry slowly instead; the socket stays usable if it recovers.
        if (line.indexOf("ACK ") === 0) {
            console.warn("MpdClient: idle refused, backing off —", line);
            root._idleChanges = [];
            idleRetry.restart();
            return;
        }

        var subs = root._idleChanges;
        root._idleChanges = [];
        root._arm();

        var queueDirty = false;
        for (var i = 0; i < subs.length; i++) {
            root.changed(subs[i]);
            if (subs[i] === "playlist") queueDirty = true;
        }
        if (subs.length === 0) return;

        // Status carries the fields every subsystem here can move (state,
        // volume, the toggles, the playlist version), so one refresh covers the
        // lot; the queue sync is chained behind it because it needs the new
        // version number that status is about to bring.
        root.send("status", function (lines) {
            root._applyStatus(lines);
            if (queueDirty && root.queueRetained) root.syncQueue();
        });
        root.refreshSong();
    }

    Timer { id: idleRetry; interval: 30000; onTriggered: root._arm(); }

    function _arm() {
        // Only the subsystems this shell reacts to, so an unrelated sticker
        // write doesn't wake us for nothing. `update` fires when a scan starts
        // and stops; `database` fires only when one actually CHANGED something,
        // which is the one the library browser has to reload on.
        idleSock.write("idle player mixer options playlist stored_playlist update database\n");
        idleSock.flush();
    }

    // MPD restarting, or not being up yet, is the normal case at login: runsv
    // brings quickshell and mpd up independently. Driven by `running` off the
    // connected property rather than the state-changed signal for the reason
    // Reach.qml documents — a connection that FAILS never enters the connected
    // state, so there is no state change to hear and the first attempt would be
    // the only one.
    Timer {
        interval: 5000
        repeat: true
        running: !cmdSock.connected || !idleSock.connected
        onTriggered: {
            if (!cmdSock.connected) cmdSock.connected = true;
            if (!idleSock.connected) idleSock.connected = true;
        }
    }
}
