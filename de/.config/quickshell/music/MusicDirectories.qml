pragma ComponentBehavior: Bound
import QtQuick
// Parent import: `Txt` (and the root singletons) live one level up. A QML
// file does NOT see its parent directory implicitly — only its own.
import ".."

// Tab 2 — the library as the tree it is on disk. One lsinfo per level (2.4ms
// for the root here), never a recursive walk. Adding a directory is still one
// command: MPD's `add` takes a directory URI and queues everything beneath it.
Item {
    id: root

    required property var client
    property real fontScale: 1.2
    function s(n) { return Config.s(n); }
    function fs(n) { return Math.round(root.s(n) * root.fontScale); }

    property string path: ""
    property var entries: []
    property bool busy: false

    // Set when Shift+A is refused at the root; cleared by moving or navigating.
    property bool refused: false
    onPathChanged: root.refused = false

    readonly property string status: root.refused
                                     ? "refusing to queue the whole library — open a folder first"
                                     : root.busy ? "reading…"
                                     : (list.count > 0 ? list.cursor + 1 : 0) + " / " + list.count

    // A ".." row whenever we are not at the root, so going up is visible.
    readonly property var rows: root.path === "" ? root.entries
                                : [{ _type: "up" }].concat(root.entries)

    function load(next) {
        root.busy = true;
        root.path = next;
        root.client.lsinfo(next, function (records) {
            root.busy = false;
            // MPD returns these interleaved; directories first reads better.
            var dirs = [], files = [], lists = [];
            for (var i = 0; i < records.length; i++) {
                if (records[i]._type === "directory") dirs.push(records[i]);
                else if (records[i]._type === "playlist") lists.push(records[i]);
                else files.push(records[i]);
            }
            // Newest first, matching rmpc's ModifiedTime(reverse: true).
            // Folders only: inside an album the files are in track order, and
            // sorting those by date would scramble the record.
            dirs.sort(root.byNewest);
            root.entries = dirs.concat(lists, files);
            list.resetCursor();
        });
    }

    // lsinfo gives a directory `Last-Modified`, which MPD derives from the
    // songs beneath it — so this is "newest music at the top". Anything without
    // the field sorts last rather than randomly.
    function byNewest(a, b) {
        var ta = a["Last-Modified"] || "";
        var tb = b["Last-Modified"] || "";
        if (ta === tb) return (a.directory || "").localeCompare(b.directory || "");
        if (ta === "") return 1;
        if (tb === "") return -1;
        return tb < ta ? -1 : 1;          // ISO-8601 sorts correctly as text
    }

    function goUp() {
        if (root.path === "") return;
        var i = root.path.lastIndexOf("/");
        root.load(i < 0 ? "" : root.path.substring(0, i));
    }

    function uriOf(row) { return row.directory || row.file || row.playlist || ""; }
    function nameOf(row) {
        var uri = root.uriOf(row);
        return uri.substring(uri.lastIndexOf("/") + 1);
    }

    function activate(i) {
        var row = root.rows[i];
        if (!row) return;
        if (row._type === "up") root.goUp();
        else if (row._type === "directory") root.load(row.directory);
        else if (row._type === "playlist") root.client.loadPlaylist(row.playlist);
        else root.client.addAndPlay(row.file);
    }

    // `a` queues without disturbing playback; a directory queues all of it.
    function addRow(i) {
        var row = root.rows[i];
        if (!row || row._type === "up") return;
        if (row._type === "playlist") root.client.loadPlaylist(row.playlist);
        else root.client.addUri(root.uriOf(row));
    }

    function handleKey(event) {
        if (list.navKey(event)) return true;
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        switch (event.key) {
        case Qt.Key_H: if (!shift) { root.goUp(); return true; } break;
        case Qt.Key_L: if (!shift) { root.activate(list.cursor); return true; } break;
        case Qt.Key_A:
            // A queues the directory we are inside. NOT at the root, where the
            // URI is "" and `add ""` queues the entire library — one keystroke
            // from this pane's opening state, and how a 6k queue became 12k.
            if (shift) {
                if (root.path === "") root.refused = true;
                else root.client.addUri(root.path);
            } else root.addRow(list.cursor);
            return true;
        }
        return false;
    }

    Component.onCompleted: root.load("")

    Txt {
        id: crumb
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: root.s(12)
        anchors.bottomMargin: 0
        height: root.s(20)
        elide: Text.ElideLeft
        font.pixelSize: root.fs(12)
        color: Theme.subtext0
        text: root.path === "" ? "/" : "/" + root.path
    }

    MusicList {
        id: list
        anchors { top: crumb.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.topMargin: root.s(4)
        rows: root.rows
        busy: root.busy
        fontScale: root.fontScale
        emptyText: "empty directory"
        onActivated: i => root.activate(i)

        rowDelegate: MusicRow {
            required property var modelData
            list: list
            icon: modelData._type === "up" ? "󰁍"
                  : modelData._type === "directory" ? "󰉋"
                  : modelData._type === "playlist" ? "󰲹" : "󰝚"
            iconColor: modelData._type === "file" ? Theme.overlay0 : Theme.blue
            label: modelData._type === "up" ? ".." : root.nameOf(modelData)
            detail: modelData._type === "file" ? (modelData.Artist || "") : ""
            onActivated: root.activate(index)
        }
    }
}
