pragma ComponentBehavior: Bound
import QtQuick
import ".."

// The C-a chooser: pick a stored playlist to add the selection to. Every tab
// can raise it — the queue's selection, a directory, a search hit — so it lives
// over the whole window rather than in a pane.
//
// A new playlist is the same `playlistadd` with a name that does not exist yet,
// so the top row is a text field rather than a separate command path.
FocusScope {
    id: root

    required property var client
    // URIs to add. A directory URI is fine; MPD expands it.
    property var uris: []

    signal closed()
    signal added(string name, int count)

    property var playlists: []
    property bool busy: false
    property bool naming: false

    // The new-playlist row sits LAST so the cursor opens on a real playlist:
    // adding to one you already have is the common case, and Enter should not
    // reflexively start typing a name.
    readonly property var rows: root.playlists.concat([{ _new: true }])

    // Built by the view's Loader when C-a asks for it, so this IS its open —
    // a fresh instance every time, already at its defaults.
    Component.onCompleted: {
        root.busy = true;
        root.client.listPlaylists(function (records) {
            root.busy = false;
            root.playlists = records;
            list.resetCursor();
        });
        root.forceActiveFocus();
    }

    function dismiss() {
        root.closed();
    }

    function commit(name) {
        var trimmed = (name || "").trim();
        if (trimmed === "" || root.uris.length === 0) return;
        root.client.playlistAdd(trimmed, root.uris);
        root.added(trimmed, root.uris.length);
        root.dismiss();
    }

    function activate(i) {
        var row = root.rows[i];
        if (!row) return;
        if (row._new) { root.naming = true; nameField.forceActiveFocus(); return; }
        root.commit(row.playlist);
    }

    // Any click outside the box dismisses, as the info/help overlay does.
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.7)
    }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(parent.width - Ui.s(80), Ui.s(460))
        height: Math.min(parent.height - Ui.s(80),
                         header.height + field.height + Ui.rowH * root.rows.length
                         + Ui.s(24))
        color: Theme.base
        border.width: 1
        border.color: Theme.surface1

        // Swallow clicks so one inside the box does not reach the dismiss area.
        MouseArea { anchors.fill: parent }

        Txt {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: Ui.s(12)
            anchors.bottomMargin: 0
            height: Ui.s(22)
            elide: Text.ElideRight
            font.pixelSize: Ui.fs(13)
            color: Theme.mauve
            text: "add " + (root.uris.length === 1 ? "this" : root.uris.length + " songs") + " to a playlist"
        }

        Item {
            id: field
            anchors { top: header.bottom; left: parent.left; right: parent.right }
            anchors.leftMargin: Ui.s(12)
            anchors.rightMargin: Ui.s(12)
            height: root.naming ? Ui.s(26) : 0
            visible: root.naming
            clip: true

            Txt {
                id: prompt
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Ui.fs(12)
                color: Theme.blue
                text: "name ›"
            }
            TextInput {
                id: nameField
                anchors.fill: parent
                anchors.leftMargin: prompt.width + Ui.s(8)
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Ui.fs(13)
                // Focused explicitly rather than by a `focus: root.naming`
                // binding, because this field's container is hidden until
                // `naming` — and an item that is not yet visible refuses
                // focus. MusicSearch can bind only because its bar is always
                // drawn. Escape hands the scope back the same way.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.naming = false;
                        root.forceActiveFocus();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.commit(nameField.text);
                        event.accepted = true;
                    }
                }
            }
        }

        MusicList {
            id: list
            anchors { top: field.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.topMargin: Ui.s(4)
            anchors.bottomMargin: Ui.s(12)
            rows: root.rows
            busy: root.busy
            onActivated: i => root.activate(i)

            rowDelegate: MusicRow {
                required property var modelData
                list: list
                icon: modelData._new ? "󰐕" : "󰲹"
                iconColor: modelData._new ? Theme.green : Theme.blue
                label: modelData._new ? "new playlist…" : modelData.playlist
                onActivated: root.activate(index)
            }
        }
    }

    Keys.onPressed: event => {
        if (root.naming) return;              // the field handles its own keys
        if (list.navKey(event)) { event.accepted = true; return; }
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            root.dismiss();
            event.accepted = true;
        }
    }
}
