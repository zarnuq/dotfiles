pragma ComponentBehavior: Bound
import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Sys, Volume,
// Reach, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

// Notification history + DND, top-right — the corner the popups themselves
// come from, so the list is where you look after one has gone.
//
// Flush to the top of the USABLE area, which is under the bar: the bar is a
// layer surface with an exclusive zone (Bar.qml), so the compositor has already
// taken that strip out of what this card can occupy. Sitting at the literal
// top of the screen, behind the bar, would need
// `WlrLayershell.exclusionMode: ExclusionMode.Ignore`.
// History + DND come from the in-process notification server (was makoctl).
Widget {
    id: root
    anchors { top: true; right: true }
    implicitWidth: s(420)
    implicitHeight: s(600)

    Column {
        anchors.fill: parent
        spacing: root.s(8)

        // Header: label + DND toggle + clear.
        Row {
            id: header
            width: parent.width
            Txt {
                text: "notifications"; color: Theme.subtext0; font.pixelSize: root.s(14)
                width: parent.width - dnd.width - clear.width - 2 * root.s(8)
                verticalAlignment: Text.AlignVCenter
            }
            HeaderBtn {
                id: dnd
                leftMargin: root.s(8)
                icon: NotificationService.paused ? "󰂛" : "󰂚"; size: root.s(14)
                onClicked: NotificationService.toggleDnd()
            }
            HeaderBtn {
                id: clear
                leftMargin: root.s(8)
                icon: "󰆴"; size: root.s(14)
                onClicked: NotificationService.clear()
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - header.height - parent.spacing
            clip: true
            spacing: root.s(5)
            model: NotificationService.history.slice(0, 8)

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
                    Txt { text: notif.modelData.app; color: Theme.subtext0; font.pixelSize: root.s(12) }
                    Txt { text: notif.modelData.summary; font.pixelSize: root.s(14)
                          width: parent.width; wrapMode: Text.WordWrap }
                }
            }
        }
    }
}
