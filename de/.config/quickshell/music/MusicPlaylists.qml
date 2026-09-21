pragma ComponentBehavior: Bound
import QtQuick
// Parent import: `Txt` (and the root singletons) live one level up. A QML
// file does NOT see its parent directory implicitly — only its own.
import ".."

// Tab 3 — stored playlists, and one level into whichever you open. Two levels
// in one pane: `opened` empty means the playlist list, otherwise its songs.
// h/l browse the same way Directories does.
Item {
    id: root

    required property var client
    property real fontScale: 1.2
    function s(n) { return Config.s(n); }
    function fs(n) { return Math.round(root.s(n) * root.fontScale); }

    property var playlists: []
    property string opened: ""
    property var songs: []
    property bool busy: false

    readonly property bool inPlaylist: root.opened !== ""
    readonly property var rows: root.inPlaylist ? root.songs : root.playlists
    readonly property string status: root.busy ? "reading…"
                                     : (list.count > 0 ? list.cursor + 1 : 0) + " / " + list.count

    function refresh() {
        root.busy = true;
        root.client.listPlaylists(function (records) {
            root.busy = false;
            records.sort((a, b) => a.playlist.localeCompare(b.playlist));
            root.playlists = records;
            if (!root.inPlaylist) list.resetCursor();
        });
    }

    function open(name) {
        root.busy = true;
        root.opened = name;
        root.client.playlistSongs(name, function (records) {
            root.busy = false;
            root.songs = records;
            list.resetCursor();
        });
    }

    function back() {
        if (!root.inPlaylist) return;
        root.opened = "";
        root.songs = [];
        list.resetCursor();
    }

    function activate(i) {
        var row = root.rows[i];
        if (!row) return;
        if (root.inPlaylist) root.client.addAndPlay(row.file);
        else root.open(row.playlist);
    }

    // `a` appends. On a playlist that is `load`, which queues the lot.
    function addRow(i) {
        var row = root.rows[i];
        if (!row) return;
        if (root.inPlaylist) root.client.addUri(row.file);
        else root.client.loadPlaylist(row.playlist);
    }

    // `D` removes the playlist itself, and only ever at the top level so it
    // cannot fire while you are looking at songs.
    function deleteRow(i) {
        var row = root.rows[i];
        if (root.inPlaylist || !row) return false;
        root.client.removePlaylist(row.playlist);
        // `rm` is not reported as a queue change, so re-read rather than wait.
        root.refresh();
        return true;
    }

    // `C-a` saves the current queue as a playlist named after the time.
    function saveQueue() {
        var now = new Date();
        root.client.savePlaylist("queue-" + Qt.formatDateTime(now, "yyyyMMdd-hhmm"));
        root.refresh();
    }

    function handleKey(event) {
        if (list.navKey(event)) return true;
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        switch (event.key) {
        case Qt.Key_H: if (!shift) { root.back(); return true; } break;
        case Qt.Key_L: if (!shift) { root.activate(list.cursor); return true; } break;
        case Qt.Key_A:
            if (ctrl) { root.saveQueue(); return true; }
            root.addRow(list.cursor);
            return true;
        case Qt.Key_D: if (shift) return root.deleteRow(list.cursor); break;
        }
        return false;
    }

    Component.onCompleted: root.refresh()

    // Saving the queue to a playlist arrives as `stored_playlist`.
    Connections {
        target: root.client
        function onChanged(subsystem) { if (subsystem === "stored_playlist") root.refresh(); }
    }

    Txt {
        id: crumb
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: root.s(12)
        anchors.bottomMargin: 0
        height: root.s(20)
        elide: Text.ElideRight
        font.pixelSize: root.fs(12)
        color: Theme.subtext0
        text: root.inPlaylist ? "󰲹 " + root.opened : "playlists    (C-a saves the queue)"
    }

    MusicList {
        id: list
        anchors { top: crumb.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.topMargin: root.s(4)
        rows: root.rows
        busy: root.busy
        fontScale: root.fontScale
        emptyText: root.inPlaylist ? "empty playlist" : "no stored playlists"
        onActivated: i => root.activate(i)

        rowDelegate: MusicRow {
            required property var modelData
            list: list
            icon: root.inPlaylist ? "󰝚" : "󰲹"
            iconColor: root.inPlaylist ? Theme.overlay0 : Theme.blue
            label: root.inPlaylist ? root.client.songTitle(modelData) : modelData.playlist
            detail: root.inPlaylist ? (modelData.Artist || "") : ""
            onActivated: root.activate(index)
        }
    }
}
