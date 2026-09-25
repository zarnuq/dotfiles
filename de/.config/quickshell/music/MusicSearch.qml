pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Tab 5 — search the library. The matching is MPD's, not ours: `search` is
// case-insensitive substring, server-side, which is exactly rmpc's Contains
// mode. So unlike the launcher's file mode there is no index to build here.
// Typing is debounced; 25ms of MPD plus a few thousand rows per keystroke is
// real work, and a half-typed word is never the query you meant.
Item {
    id: root

    required property var client

    property string query: ""
    property var results: []
    property bool busy: false
    // Modal, like vim: the pane opens in NORMAL mode, so 1-5, j/k and every
    // global key still work on this tab. `i` or `/` enters insert mode and the
    // field takes the keyboard; Escape hands it straight back.
    property bool typing: false

    // rmpc's tag list, same order.
    readonly property var tags: ["any", "artist", "album", "albumartist", "title", "genre", "filename"]
    property int tagIndex: 0
    readonly property string tag: root.tags[root.tagIndex]

    readonly property string status: {
        if (root.busy) return "searching…";
        if (root.typing) return "-- INSERT --   Esc leaves the field";
        if (root.query === "") return "i or / to search · j/k to move · T changes the tag";
        return root.results.length + (root.results.length === 1 ? " match" : " matches");
    }

    function cycleTag(direction) {
        root.tagIndex = (root.tagIndex + direction + root.tags.length) % root.tags.length;
        if (root.query !== "") root.run();
    }

    function run() {
        if (root.query === "") { root.results = []; return; }
        root.busy = true;
        var sentQuery = root.query, sentTag = root.tag;
        root.client.search(sentTag, sentQuery, function (records) {
            // A slow earlier search must not overwrite a newer one.
            // Clear `busy` even when superseded: clearing the field stops any
            // further run(), so an early return here left the pane reading
            // "searching…" for the rest of its life.
            root.busy = false;
            if (sentQuery !== root.query || sentTag !== root.tag) return;
            root.results = records;
            list.resetCursor();
        });
    }

    function activate(i) {
        if (root.results[i]) root.client.addAndPlay(root.results[i].file);
    }
    function addRow(i) {
        if (root.results[i]) root.client.addUri(root.results[i].file);
    }
    // `A` queues every match as one command list, so a broad search is still
    // a single round trip.
    function addAll() {
        var commands = [];
        for (var i = 0; i < root.results.length; i++)
            commands.push("add " + root.client.q(root.results[i].file));
        root.client.sendList(commands);
    }

    function focusField() { root.typing = true; field.forceActiveFocus(); }

    /// Hand the keyboard back. `typing = false` alone was not enough: nothing
    /// moved focus off the TextInput, so every subsequent key still went into
    /// the query — j/k typed letters, and q/Escape could not close the window.
    signal focusReleased()
    function leaveField() {
        if (!root.typing) return;
        root.typing = false;      // clears `focus:` on the field
        root.focusReleased();
    }

    /// What C-a adds from here: the hit under the cursor.
    function selectionUris() { return list.currentUris(); }

    function handleKey(event) {
        if (root.typing) return false;      // the field handles its own keys
        if (list.navKey(event)) return true;
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        switch (event.key) {
        case Qt.Key_A:
            if (shift) root.addAll(); else root.addRow(list.cursor);
            return true;
        case Qt.Key_T: if (shift) { root.cycleTag(1); return true; } break;
        case Qt.Key_I:
        case Qt.Key_Slash: root.focusField(); return true;
        }
        return false;
    }

    Timer { id: debounce; interval: 180; onTriggered: root.run() }

    Item {
        id: bar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: Ui.s(12)
        anchors.bottomMargin: 0
        height: Ui.s(24)

        Txt {
            id: tagLabel
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Ui.fs(12)
            color: Theme.mauve
            text: root.tag + " ›"
        }

        Field {
            id: field
            anchors.fill: parent
            anchors.leftMargin: tagLabel.width + Ui.s(8)
            font.pixelSize: Ui.fs(13)
            // Bound, not just set once. forceActiveFocus() on the parent
            // FocusScope delegates straight back to a focused child, so
            // releasing has to clear this — the same shape MusicStatusBar uses
            // for the queue's search field.
            focus: root.typing
            text: root.query
            onTextChanged: {
                root.query = text;
                if (text === "") { root.results = []; debounce.stop(); }
                else debounce.restart();
            }
            Keys.onPressed: event => {
                // Escape always returns to normal mode — never straight out of
                // the window, which is what makes a second Escape close it.
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Down) {
                    root.leaveField();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    debounce.stop();
                    root.run();
                    root.leaveField();
                    event.accepted = true;
                } else if (event.key === Qt.Key_T && (event.modifiers & Qt.ControlModifier)) {
                    root.cycleTag(1);
                    event.accepted = true;
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text === ""
                color: Theme.surface1
                font.pixelSize: Ui.fs(13)
                text: "search the library"
            }
        }
    }

    MusicList {
        id: list
        anchors { top: bar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.topMargin: Ui.s(4)
        rows: root.results
        busy: root.busy
        emptyText: root.query === "" ? "" : "no matches"
        onActivated: i => root.activate(i)

        rowDelegate: MusicRow {
            required property var modelData
            list: list
            icon: "󰝚"
            label: root.client.songTitle(modelData)
            detail: modelData.Artist || ""
            current: root.client.song.file !== undefined
                     && modelData.file === root.client.song.file
            onActivated: root.activate(index)
        }
    }
}
