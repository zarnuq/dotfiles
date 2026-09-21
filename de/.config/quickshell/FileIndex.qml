pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "FileSearch.js" as FileSearch

// Lifecycle and fd enumeration behind the launcher's "/" mode.
// FileSearch.js owns indexing, symlink deduplication, ranking and query caching.
// Walking without -L avoids following nix symlink farms into millions of entries.
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

    // Replaced as a unit on ingest and released after the launcher goes idle.
    property var _index: null

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
        root._index = null;
        root.count = 0; root.ready = false;
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

    function ingest(text) {
        root._index = FileSearch.createIndex(text, root._pairs, root.demoted);
        root.count = root._index.paths.length;
        root.ready = true;
    }

    function search(rawq, limit) {
        return FileSearch.search(root._index, rawq, limit, root.home);
    }
}
