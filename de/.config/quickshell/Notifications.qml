import Quickshell
import QtQuick

// eww `notifications` window. Bottom-left, x=140 y=600, 280 wide.
// History + DND now come from the in-process Notifs server (was makoctl).
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(600); left: s(140) }
    implicitWidth: s(280)
    implicitHeight: s(150)

    Column {
        anchors.fill: parent
        spacing: root.s(8)

        // Header: label + DND toggle + clear.
        Row {
            id: header
            width: parent.width
            Txt {
                text: "notifications"; color: Theme.subtext0; font.pixelSize: root.s(12)
                width: parent.width - dnd.width - clear.width - 2 * root.s(8)
                verticalAlignment: Text.AlignVCenter
            }
            HeaderBtn {
                id: dnd
                leftMargin: root.s(8)
                icon: Notifs.paused ? "󰂛" : "󰂚"; size: root.s(14)
                onClicked: Notifs.toggleDnd()
            }
            HeaderBtn {
                id: clear
                leftMargin: root.s(8)
                icon: "󰆴"; size: root.s(14)
                onClicked: Notifs.clear()
            }
        }

        ListView {
            width: parent.width
            height: parent.height - header.height - parent.spacing
            clip: true
            spacing: root.s(5)
            model: Notifs.history.slice(0, 5)

            delegate: Rectangle {
                id: notif
                required property var modelData
                width: ListView.view.width
                color: Theme.surface0; radius: root.s(8)
                implicitHeight: card.height + root.s(16)
                Column {
                    id: card
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: root.s(8); rightMargin: root.s(8) }
                    Txt { text: notif.modelData.app; color: Theme.subtext0; font.pixelSize: root.s(10) }
                    Txt { text: notif.modelData.summary; font.pixelSize: root.s(12)
                          width: parent.width; wrapMode: Text.WordWrap }
                }
            }
        }
    }
}
