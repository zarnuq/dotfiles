pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Tab 2 — the library as the tree it is on disk. One lsinfo per level (2.4ms
// for the root here), never a recursive walk. Adding a directory is still one
// command: MPD's `add` takes a directory URI and queues everything beneath it.
Item {
    id: root

    required property var client

    property string path: ""
    property var entries: []
    property bool busy: false

    readonly property string status: root.busy ? "reading…" : list.position

    // A ".." row whenever we are not at the root, so going up is visible.
    readonly property var rows: root.path === "" ? root.entries
                                : [{ _type: "up" }].concat(root.entries)

    /// `keepCursor` is for re-reading the level already in view: descending is
    /// what should land you at the top, a background rescan is not.
    function load(next, keepCursor) {
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
            // moveTo clamps, so a level that shrank under us cannot leave the
            // cursor past the end.
            if (keepCursor) list.moveTo(list.cursor);
            else list.resetCursor();
        });
    }

    // MPD reports `database` only when a scan actually changed something, so
    // this is not a reload per `update` keystroke. Without it the browser kept
    // showing the listing from whenever the tab was first opened.
    Connections {
        target: root.client
        function onChanged(subsystem) {
            if (subsystem === "database") root.load(root.path, true);
        }
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

    /// What C-a adds from here. A directory URI is fine — MPD expands it into
    /// the playlist the same way it expands one into the queue. A stored
    /// playlist row is not a URI, so it offers nothing.
    function selectionUris() {
        var row = root.rows[list.cursor];
        if (!row || row._type === "up" || row._type === "playlist") return [];
        var uri = root.uriOf(row);
        return uri ? [uri] : [];
    }

    function handleKey(event) {
        if (list.navKey(event)) return true;
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        switch (event.key) {
        case Qt.Key_H: if (!shift) { root.goUp(); return true; } break;
        case Qt.Key_L: if (!shift) { root.activate(list.cursor); return true; } break;
        case Qt.Key_A:
            // A queues the directory we are INSIDE, which at the root means the
            // URI "" — and `add ""` is MPD's whole library. That is deliberate:
            // it is rmpc's AddAll, and the usual way to queue everything before
            // shuffling. It is also how a 6k queue silently became 12k, so
            // remember that a second press appends the library again.
            if (shift) root.client.addUri(root.path);
            else root.addRow(list.cursor);
            return true;
        }
        return false;
    }

    Component.onCompleted: root.load("")

    MusicCrumb {
        id: crumb
        elide: Text.ElideLeft
        text: root.path === "" ? "/" : "/" + root.path
    }

    MusicList {
        id: list
        anchors { top: crumb.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.topMargin: Ui.s(4)
        rows: root.rows
        busy: root.busy
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
