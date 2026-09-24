pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Tab 3 — stored playlists, and one level into whichever you open. Two levels
// in one pane: `opened` empty means the playlist list, otherwise its songs.
// h/l browse the same way Directories does.
Item {
    id: root

    required property var client

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
            root.playlists = records;
            if (!root.inPlaylist) list.resetCursor();
        });
    }

    function open(name) {
        root.opened = name;
        root._read(false);
    }

    // Re-read in place after an edit; moveTo clamps, so a deleted last row
    // cannot strand the cursor.
    function reopen() {
        if (root.inPlaylist) root._read(true);
    }

    function _read(keepCursor) {
        root.busy = true;
        root.client.playlistSongs(root.opened, function (records) {
            root.busy = false;
            root.songs = records;
            if (keepCursor) list.moveTo(list.cursor);
            else list.resetCursor();
        });
    }

    function back() {
        if (!root.inPlaylist) return;
        root.opened = "";
        root.songs = [];
        list.resetCursor();
        // Catches up on edits made while we were inside a playlist.
        root.refresh();
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

    // `d` removes ONE song, and only inside a playlist — the mirror of `D`, so
    // neither can fire at the level the other belongs to. MPD deletes by
    // position, and the row index is that position: listplaylistinfo returns
    // the playlist in order and carries no Pos of its own.
    function deleteSong(i) {
        if (!root.inPlaylist || !root.songs[i]) return false;
        // No callback re-read: idle reports stored_playlist and reopens us.
        root.client.playlistRemoveAt(root.opened, i);
        return true;
    }

    /// What C-a adds from here: the song under the cursor. A playlist row is
    /// not a URI MPD can add to another playlist, so the top level offers none.
    function selectionUris() { return root.inPlaylist ? list.currentUris() : []; }

    // `C-s` saves the current queue as a playlist named after the time. (It was
    // C-a until that key became "add the selection to a playlist" everywhere.)
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
            root.addRow(list.cursor);
            return true;
        case Qt.Key_S: if (ctrl) { root.saveQueue(); return true; } break;
        // navKey has already taken C-d, so this is the plain pair: D removes
        // the playlist, d removes the song under the cursor.
        case Qt.Key_D:
            return shift ? root.deleteRow(list.cursor) : root.deleteSong(list.cursor);
        }
        return false;
    }

    Component.onCompleted: root.refresh()

    // Saving the queue to a playlist arrives as `stored_playlist`.
    Connections {
        target: root.client
        // Only the level in view; back() re-reads the other one.
        function onChanged(subsystem) {
            if (subsystem !== "stored_playlist") return;
            if (root.inPlaylist) root.reopen();
            else root.refresh();
        }
    }

    Txt {
        id: crumb
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: Ui.s(12)
        anchors.bottomMargin: 0
        height: Ui.s(20)
        elide: Text.ElideRight
        font.pixelSize: Ui.fs(12)
        color: Theme.subtext0
        text: root.inPlaylist ? "󰲹 " + root.opened : "playlists    (C-s saves the queue)"
    }

    MusicList {
        id: list
        anchors { top: crumb.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.topMargin: Ui.s(4)
        rows: root.rows
        busy: root.busy
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
