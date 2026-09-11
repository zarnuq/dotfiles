pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// File index + ranker behind the launcher's "/" mode.
//
// Two separate problems, and conflating them is why a plain `fd | fzf` over
// $HOME is unusable here:
//
// 1. THE CORPUS. fzf/find following symlinks walks .nix-defexpr/channels and
//    .local/state/nix/profiles straight into /nix/store, and $HOME goes from
//    ~46k entries to ~3.6M — almost all of it duplicate nix channel trees
//    (that is where the screens full of `home-manager/po/*.po` come from).
//    `fd` without -L never leaves the real tree; the excludes below drop the
//    rest of the machinery. 3.6M -> ~46k, enumerated in ~0.1s.
//
// 2. THE MATCH. fzf scores a subsequence anywhere in the WHOLE PATH, so
//    "home-manager" happily matches .../home-manager/po/tok.po — the query
//    matched the directory, and the file it returned has nothing to do with
//    it. Here a query matches the BASENAME unless it contains a "/", in which
//    case it matches the whole path. Subsequence-fuzzy is kept, but only as a
//    last resort below every literal tier, and span-capped so it can't reach
//    across half a filename.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "~"

    // Directory names pruned at walk time. Big, machine-generated, and never
    // what you meant: caches, game/browser data, the stowed icon+font themes
    // (~95k files between them), and the nix symlink farms.
    readonly property var excludes: [
        ".cache", ".git", "node_modules", "__pycache__", "venv", ".venv",
        "Steam", "Trash", ".zen", ".mozilla", ".thunderbird",
        "icons", "fonts", ".nix-defexpr", ".local/state", ".codex", ".claude"
    ]

    // Paths that exist but are almost never the answer. Not excluded — you may
    // genuinely want a wallpaper or a lyric file — just pushed below real hits.
    readonly property var demoted: [
        "/.local/share/", "/site-packages/", "/SecLists/", "/Music/", "/Downloads/"
    ]

    property bool ready: false
    property bool building: false
    property int count: 0

    // ── the index ──────────────────────────────────────────────────────
    // Built once per enumeration, never per keystroke: lowercasing 46k paths
    // on every character typed is the whole cost of a naive filter.
    property var _path: []        // display path, trailing "/" stripped
    property var _base: []        // lowercased basename, leading "." stripped
    property var _lpath: []       // lowercased full path
    property var _penalty: null   // depth + hidden + demoted, precomputed
    property var _isDir: null

    // link path -> resolved target, for the 115-odd symlinks in the tree.
    property var _pairs: []

    function _walk(extra) {
        var cmd = ["fd", "--hidden", "--absolute-path"];
        for (var i = 0; i < root.excludes.length; i++) cmd.push("--exclude", root.excludes[i]);
        cmd.push(".", root.home);
        for (var j = 0; j < extra.length; j++) cmd.push(extra[j]);
        return cmd;
    }

    // Two passes, symlinks first, because the main walk has to know which of
    // its entries to drop before it indexes them. The link pass is its own
    // command rather than a flag on the walk because fd can report a link's
    // target only through --exec; -x (parallel, ~0.24s for 115 links) beats
    // -X with a shell loop, which serialises the readlinks.
    function build() {
        if (root.building) return;
        root.building = true;
        root._pairs = [];
        linkProc.command = root._walk([
            "--type", "l", "-x", "sh", "-c",
            'printf "%s\t%s\n" "$1" "$(readlink -f -- "$1")"', "_", "{}"
        ]);
        linkProc.running = true;
    }

    // Dropped when the launcher has been shut for a while: ~46k JS strings is
    // ~10 MB, and a rebuild is a tenth of a second. Held while in use so
    // typing never waits on fd.
    function release() {
        root._path = []; root._base = []; root._lpath = [];
        root._penalty = null; root._isDir = null;
        root.count = 0; root.ready = false;
        root._lastQuery = ""; root._lastCand = null;
    }

    Process {
        id: linkProc
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], rows = text.split("\n");
                for (var i = 0; i < rows.length; i++) {
                    var tab = rows[i].indexOf("\t");
                    if (tab > 0) out.push([rows[i].slice(0, tab), rows[i].slice(tab + 1)]);
                }
                root._pairs = out;
                proc.command = root._walk([]);
                proc.running = true;
            }
        }
        // fd missing, or no symlinks at all: index everything, dedupe nothing.
        onExited: if (!proc.running && root.building && root._pairs.length === 0) {
            proc.command = root._walk([]);
            proc.running = true;
        }
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                root.ingest(text);
                root.building = false;
            }
        }
    }

    // Stow gives every config two names — ~/.config/home-manager is a symlink
    // to ~/dotfiles/de/.config/home-manager — and both show up as separate
    // hits for the same directory. 89 of this tree's 115 symlinks are that
    // kind of duplicate.
    //
    // The LINK is what gets dropped, not the target: fd never descends a
    // symlink, so the link side has no indexed children while the target side
    // has all of them. Keeping the target is what makes a parent and its
    // contents agree about where they live. (Flip the two pushes below if the
    // ~/.config name is the one you'd rather see.)
    function _dropSet(lines, n) {
        var pairs = root._pairs;
        if (pairs.length === 0) return null;

        var wanted = {}, k;
        for (k = 0; k < pairs.length; k++) wanted[pairs[k][1]] = false;

        // One cheap sweep: only the ~115 targets are ever looked up, so this
        // is a hash miss per line rather than a 46k-key set of the whole tree.
        for (var i = 0; i < n; i++) {
            var p = lines[i];
            if (p.charCodeAt(p.length - 1) === 47) p = p.slice(0, -1);
            if (wanted[p] === false) wanted[p] = true;
        }

        var drop = null;
        for (k = 0; k < pairs.length; k++) {
            if (wanted[pairs[k][1]] !== true) continue;   // target isn't indexed: keep the link
            if (drop === null) drop = {};
            drop[pairs[k][0]] = true;
        }
        return drop;
    }

    function ingest(text) {
        var lines = text.split("\n");
        var n = lines.length;
        if (n > 0 && lines[n - 1] === "") n--;

        var drop = root._dropSet(lines, n);

        // Pushed rather than preallocated: dropped links make the output
        // shorter than the input, and every parallel array has to stay aligned.
        var path = [], base = [], lpath = [], pens = [], dirs = [];
        var dem = root.demoted;

        for (var i = 0; i < n; i++) {
            var p = lines[i], isDir = 0;
            if (p.charCodeAt(p.length - 1) === 47) {   // fd marks dirs with a trailing /
                p = p.slice(0, -1);
                isDir = 1;
            }
            if (drop !== null && drop[p] === true) continue;

            var lower = p.toLowerCase();
            var b = lower.slice(lower.lastIndexOf("/") + 1);
            if (b.charCodeAt(0) === 46) b = b.slice(1);   // ".zshrc" is found by "zshrc"

            var depth = 0;
            for (var j = 0; j < p.length; j++) if (p.charCodeAt(j) === 47) depth++;
            var pen = depth * 3;                          // shallower is likelier
            if (lower.indexOf("/.") >= 0) pen += 12;      // dotfile machinery
            for (var k = 0; k < dem.length; k++)
                if (p.indexOf(dem[k]) >= 0) { pen += 120; break; }

            path.push(p); lpath.push(lower); base.push(b);
            pens.push(pen); dirs.push(isDir);
        }

        var m = path.length;
        var penalty = new Int16Array(m), isDirs = new Uint8Array(m);
        for (var q = 0; q < m; q++) { penalty[q] = pens[q]; isDirs[q] = dirs[q]; }

        root._path = path; root._base = base; root._lpath = lpath;
        root._penalty = penalty; root._isDir = isDirs;
        root.count = m;
        root._lastQuery = ""; root._lastCand = null;
        root.ready = true;
    }

    // ── matching ───────────────────────────────────────────────────────

    // Is `q` a subsequence of `hay`, and how far apart are its characters?
    // Span is what separates "Bar.qml" from a query's letters scattered across
    // a 90-character track title.
    function _subseq(hay, q) {
        var i = 0, first = -1, last = -1;
        for (var j = 0; j < hay.length && i < q.length; j++) {
            if (hay.charCodeAt(j) === q.charCodeAt(i)) {
                if (first < 0) first = j;
                last = j;
                i++;
            }
        }
        return i === q.length ? last - first + 1 : -1;
    }

    // Incremental narrowing. Candidacy (subsequence) is monotone in the query,
    // so a longer query can only match a subset of what the previous one did:
    // after the first keystroke pays for the full 46k scan, the rest are scored
    // against a handful of survivors — ~1ms a character instead of ~120ms.
    // Candidacy is deliberately the LOOSEST rule even when the score then
    // rejects the entry; gating the pool on the score would make it non-monotone
    // and silently lose matches as you type.
    property string _lastQuery: ""
    property var _lastCand: null

    function _slashes(str) {
        var n = 0;
        for (var i = 0; i < str.length; i++) if (str.charCodeAt(i) === 47) n++;
        return n;
    }

    // Score `q` against one haystack, literal tiers first, fuzzy last.
    // Returns -1 for "not a candidate at all".
    function _tier(hay, q, maxSpan) {
        var idx = hay.indexOf(q);
        if (idx === 0) return hay.length === q.length ? 1000 : 800 - (hay.length - q.length);
        if (idx > 0) {
            var c = hay.charCodeAt(idx - 1);        // 45 - · 95 _ · 46 . · 32 space · 47 /
            var boundary = c === 45 || c === 95 || c === 46 || c === 32 || c === 47;
            return (boundary ? 600 : 400) - idx;
        }
        // Native indexOf on the first character before entering the JS scan:
        // nearly every one of 46k entries is a miss, and this is what makes the
        // cold scan a C++ memchr rather than a per-character interpreter loop.
        if (hay.indexOf(q.charAt(0)) < 0) return -1;
        var span = root._subseq(hay, q);
        if (span < 0) return -1;
        if (q.length < 4 || span > maxSpan) return 0;   // candidate, but not shown
        return 150 - (span - q.length) * 4;
    }

    function search(rawq, limit) {
        if (!root.ready || rawq === "") return [];

        var q = rawq.toLowerCase();
        var cut = q.lastIndexOf("/");

        // A "/" in the query splits it: everything before the last slash must
        // appear in the directory, everything after is matched against the
        // basename as usual. NOT a fuzzy match over the whole path — that is
        // what makes a plain fzf return .../home-manager/po/tok.po for
        // "home-manager": the query matched the directory and the file it
        // handed back was unrelated. The directory half is a plain substring
        // for the same reason; subsequence-matching a path is all noise.
        var dirQ = cut >= 0 ? q.slice(0, cut) : "";
        var baseQ = cut >= 0 ? q.slice(cut + 1) : q;

        var reuse = root._lastCand !== null
                    && q.length > root._lastQuery.length
                    && q.indexOf(root._lastQuery) === 0
                    && root._slashes(q) === root._slashes(root._lastQuery);

        var pool = reuse ? root._lastCand : null;
        var n = pool ? pool.length : root.count;
        var base = root._base, lpath = root._lpath, penalty = root._penalty;
        var maxSpan = baseQ.length * 2 + 4;
        var cand = [], scored = [];

        for (var k = 0; k < n; k++) {
            var i = pool ? pool[k] : k;

            var s;
            if (baseQ === "") {
                s = 700;                            // "dir/" — list what is under it
            } else {
                s = root._tier(base[i], baseQ, maxSpan);
                if (s < 0) continue;
                cand.push(i);
                if (s === 0) continue;
            }

            if (dirQ !== "") {
                var full = lpath[i];
                var at = full.indexOf(dirQ);
                // Must land in the directory half, not in the filename.
                if (at < 0 || at + dirQ.length > full.lastIndexOf("/")) continue;
                s += 60;
            }

            s -= penalty[i];
            // One number per hit rather than a {score, index} pair: object
            // allocation is most of the cost of a naive ranker at this size.
            if (s > 0) scored.push(s * 1000000 + i);
        }

        root._lastQuery = q;
        if (baseQ !== "") root._lastCand = cand;
        else root._lastCand = null;

        scored.sort(function (a, b) { return b - a; });

        var out = [], max = Math.min(limit, scored.length);
        for (var m = 0; m < max; m++) {
            var v = scored[m], id = v % 1000000, path = root._path[id];
            var slash = path.lastIndexOf("/");
            out.push({
                path: path,
                name: path.slice(slash + 1),
                dir: path.slice(0, slash).replace(root.home, "~"),
                isDir: root._isDir[id] === 1
            });
        }
        return out;
    }
}
