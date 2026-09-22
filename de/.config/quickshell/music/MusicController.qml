import QtQuick

// Pure state: imports nothing but QtQuick, and deliberately so — that is what
// lets tests/quickshell/tst_music_controller.qml load it standalone under
// qmltestrunner. Reaching for Config.s() or Theme here would pull in the root
// directory, which imports Quickshell, and the suite would stop running.
QtObject {
    id: root

    required property var client

    signal closeRequested()
    signal revealRequested()
    signal resetRequested()

    property int cursor: 0
    property int viewportRows: 20
    // MPD keeps song IDs stable when queue positions change.
    property var marked: ({})
    readonly property int markedCount: Object.keys(root.marked).length
    property string query: ""
    property bool searching: false
    property string overlay: ""
    property int tab: 0

    readonly property var tabs: [
        { name: "Queue" }, { name: "Directories" }, { name: "Playlists" },
        { name: "Lyrics" }, { name: "Search" }
    ]
    // The live pane for the current tab, set by the view. Null on the queue,
    // which the controller drives itself.
    property var pane: null
    readonly property var queue: root.client ? root.client.queue : []
    readonly property var current: root.cursor >= 0 && root.cursor < root.queue.length
                                   ? root.queue[root.cursor] : null
    property ListModel rowModel: ListModel {}
    property var _prevQueue: []
    // Transient confirmation that something reached the queue.
    property string notice: ""
    property Timer noticeTimer: Timer { interval: 2600; onTriggered: root.notice = ""; }
    // Where the last diff inserted, so a single add can be named.
    property var _lastInsert: ({ at: 0, count: 0, removed: 0 })
    // Set once a non-empty queue has been seen, so the initial load of several
    // thousand songs is not announced as an addition.
    property bool _primed: false
    property var _hay: []
    property bool _ready: false
    property bool _jumpPending: false

    property Connections clientConnections: Connections {
        target: root.client
        function onSongPosChanged() { root.resolvePendingJump(); }
    }

    Component.onCompleted: {
        root._ready = true;
        root.updateQueue();
    }
    onQueueChanged: if (root._ready) root.updateQueue();

    // Preserve unchanged model rows so edits do not reset the ListView.
    function syncRows(oldQueue, newQueue) {
        var oldCount = oldQueue.length;
        var newCount = newQueue.length;
        var limit = Math.min(oldCount, newCount);
        var prefix = 0;
        while (prefix < limit && oldQueue[prefix].Id === newQueue[prefix].Id) prefix++;
        var suffix = 0;
        while (suffix < limit - prefix
               && oldQueue[oldCount - 1 - suffix].Id === newQueue[newCount - 1 - suffix].Id)
            suffix++;

        var removeCount = oldCount - prefix - suffix;
        var insertCount = newCount - prefix - suffix;
        if (removeCount > 0) root.rowModel.remove(prefix, removeCount);
        for (var i = 0; i < insertCount; i++) {
            if (prefix + i >= root.rowModel.count) root.rowModel.append({ n: 0 });
            else root.rowModel.insert(prefix + i, { n: 0 });
        }
        root._lastInsert = { at: prefix, count: insertCount, removed: removeCount };
    }

    function updateQueue() {
        var hay = new Array(root.queue.length);
        var marks = {};
        for (var i = 0; i < root.queue.length; i++) {
            var song = root.queue[i];
            hay[i] = ((song.Title || song.file || "") + " " + (song.Artist || "") + " "
                      + (song.Album || "")).toLowerCase();
            if (root.isMarked(song)) marks[song.Id] = true;
        }
        var grew = root.queue.length - root._prevQueue.length;
        root.syncRows(root._prevQueue, root.queue);
        root._prevQueue = root.queue;
        // Net growth, not the diff's insert count: reordering with J/K inserts
        // and removes the same span and must not read as an addition.
        // Ask the client whether this was a wholesale fetch. Gating on "the
        // queue was empty before" instead swallowed a genuine first add when
        // the window was opened on an empty queue.
        if (root._primed && grew > 0 && !root.client.queueWasBulk) root.announceAdded(grew);
        root._primed = true;
        root._hay = hay;
        root.marked = marks;
        if (root.cursor >= root.queue.length) root.cursor = Math.max(0, root.queue.length - 1);
        root.resolvePendingJump();
    }

    function notify(text) {
        root.notice = text;
        root.noticeTimer.restart();
    }

    function announceAdded(count) {
        // Only name the song for a CLEAN single insert. When a batch both
        // removes and adds — another client rewriting part of the queue —
        // net growth can be 1 while the row at the change point is not the
        // added one, and the banner named an unrelated track.
        var clean = root._lastInsert.count === 1 && root._lastInsert.removed === 0;
        var song = clean ? root.queue[root._lastInsert.at] : null;
        root.notify(song ? "Added  " + root.client.songTitle(song)
                         : "Added  " + count + (count === 1 ? " song" : " songs"));
    }

    function resolvePendingJump() {
        if (root._jumpPending && root.jumpToCurrent()) {
            root._jumpPending = false;
            // The view defers scrolling until newly inserted rows are laid out.
            root.revealRequested();
        }
    }

    function matches(i) {
        return root.query !== "" && root._hay[i] !== undefined
               && root._hay[i].indexOf(root.query.toLowerCase()) >= 0;
    }

    function findMatch(from, direction) {
        var count = root.queue.length;
        if (count === 0 || root.query === "") return -1;
        for (var step = 1; step <= count; step++) {
            var i = ((from + direction * step) % count + count) % count;
            if (root.matches(i)) return i;
        }
        return -1;
    }

    function jumpMatch(direction) {
        var i = root.findMatch(root.cursor, direction);
        if (i >= 0) root.cursor = i;
    }

    function updateQuery(text) {
        root.query = text;
        if (text === "" || root.matches(root.cursor)) return;
        var i = root.findMatch(root.cursor - 1, 1);
        if (i >= 0) root.cursor = i;
    }

    function finishSearch(cancel) {
        if (cancel) root.query = "";
        root.searching = false;
    }

    function moveTo(i) {
        if (root.queue.length > 0)
            root.cursor = Math.max(0, Math.min(root.queue.length - 1, i));
    }

    function moveBy(delta) { root.moveTo(root.cursor + delta); }

    function jumpToCurrent() {
        if (root.client.songPos < 0 || root.client.songPos >= root.queue.length) return false;
        root.moveTo(root.client.songPos);
        return true;
    }

    function isMarked(song) { return song && root.marked[song.Id] === true; }

    function toggleMark() {
        var song = root.current;
        if (!song) return;
        var next = {};
        for (var key in root.marked) next[key] = root.marked[key];
        if (next[song.Id]) delete next[song.Id];
        else next[song.Id] = true;
        root.marked = next;
        root.moveBy(1);
    }

    function invertMarks() {
        var next = {};
        for (var i = 0; i < root.queue.length; i++) {
            var id = root.queue[i].Id;
            if (!root.marked[id]) next[id] = true;
        }
        root.marked = next;
    }

    function clearMarks() { root.marked = ({}); }

    function targets() {
        if (root.markedCount === 0) return root.current ? [root.current] : [];
        var rows = [];
        for (var i = 0; i < root.queue.length; i++)
            if (root.isMarked(root.queue[i])) rows.push(root.queue[i]);
        return rows;
    }

    function playSelected() {
        if (root.current) root.client.playId(root.current.Id);
    }

    function deleteSelected() {
        var rows = root.targets();
        if (rows.length === 0) return;
        var commands = [];
        for (var i = 0; i < rows.length; i++) commands.push("deleteid " + rows[i].Id);
        root.client.sendList(commands);
        root.clearMarks();
    }

    function moveSelected(direction) {
        var song = root.current;
        if (!song || root.markedCount > 0) return;
        var from = parseInt(song.Pos);
        var to = from + direction;
        if (to < 0 || to >= root.queue.length) return;
        root.client.moveSong(from, to);
        root.cursor = to;
    }

    function reset() {
        root.query = "";
        root.searching = false;
        root.overlay = "";
        root.clearMarks();
        root._jumpPending = !root.jumpToCurrent();
        root.resetRequested();
    }

    function setTab(i) {
        if (i < 0 || i >= root.tabs.length || i === root.tab) return;
        root.searching = false;
        root.tab = i;
    }

    function cycleTab(direction) {
        root.setTab((root.tab + direction + root.tabs.length) % root.tabs.length);
    }

    function handleKey(event) {
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        if (root.overlay !== "") {
            root.overlay = "";
            event.accepted = true;
            return;
        }
        if (root.searching) return;

        event.accepted = true;

        // The visible pane gets first refusal, so a tab can own a key the
        // globals below also use — `i` is insert mode on the Search tab and
        // the info overlay everywhere else. Every pane guards its modifiers
        // (h/l but not H/L, and so on), so the globals still reach here.
        if (root.tab !== 0 && root.pane && root.pane.handleKey && root.pane.handleKey(event))
            return;

        switch (event.key) {
        case Qt.Key_P: root.client.toggle(); return;
        case Qt.Key_S: root.client.stop(); return;
        case Qt.Key_L: if (shift) { root.client.next(); return; } break;
        case Qt.Key_H: if (shift) { root.client.previous(); return; } break;
        // Arrow keys control playback; j/k navigate the queue.
        case Qt.Key_Up: root.client.changeVolume(5); return;
        case Qt.Key_Down: root.client.changeVolume(-5); return;
        case Qt.Key_Right: root.client.seekBy(5); return;
        case Qt.Key_Left: root.client.seekBy(-5); return;
        case Qt.Key_Z: if (shift) { root.client.toggleRepeat(); return; } break;
        case Qt.Key_X: if (shift) { root.client.toggleRandom(); return; } break;
        case Qt.Key_C: if (shift) { root.client.toggleConsume(); return; } break;
        case Qt.Key_V: if (shift) { root.client.toggleSingle(); return; } break;
        case Qt.Key_QuoteLeft:
        case Qt.Key_AsciiTilde: root.overlay = "help"; return;
        case Qt.Key_I: root.overlay = "info"; return;
        case Qt.Key_Q:
        case Qt.Key_Escape: root.closeRequested(); return;
        case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: case Qt.Key_4: case Qt.Key_5:
            root.setTab(event.key - Qt.Key_1); return;
        case Qt.Key_Tab: root.cycleTab(1); return;
        case Qt.Key_Backtab: root.cycleTab(-1); return;
        }

        // The queue bindings below would act on rows that are not on screen.
        if (root.tab !== 0) { event.accepted = false; return; }
        switch (event.key) {
        case Qt.Key_C: root.jumpToCurrent(); return;
        case Qt.Key_J:
            if (shift) root.moveSelected(1); else root.moveBy(1);
            return;
        case Qt.Key_K:
            if (shift) root.moveSelected(-1); else root.moveBy(-1);
            return;
        case Qt.Key_G:
            root.moveTo(shift ? root.queue.length - 1 : 0); return;
        case Qt.Key_Space:
            if (ctrl) root.invertMarks(); else root.toggleMark();
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter: root.playSelected(); return;
        case Qt.Key_Slash: root.searching = true; root.query = ""; return;
        case Qt.Key_N: root.jumpMatch(shift ? -1 : 1); return;
        case Qt.Key_D:
            // The queue's Shift+D binding takes priority over Ctrl+D.
            if (shift) { root.client.clearQueue(); root.clearMarks(); return; }
            if (ctrl) { root.moveBy(Math.floor(root.viewportRows / 2)); return; }
            root.deleteSelected(); return;
        case Qt.Key_U:
            if (ctrl) { root.moveBy(-Math.floor(root.viewportRows / 2)); return; }
            break;
        }
        event.accepted = false;
    }
}
