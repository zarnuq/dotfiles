pragma ComponentBehavior: Bound
import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Sys, Volume,
// Reach, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

// A card's title row: icon, a subtext0 label, then whatever the card puts
// inside it (a value readout, a HeaderBtn) pinned to the right edge. The label
// fills what the icon and that trailing slot leave — each card used to compute
// that width itself by subtracting its neighbours by id.
Row {
    id: root

    property string icon: ""
    property color iconColor: Theme.text
    property real iconSize: Config.s(18)
    property string label: ""
    default property alias trailing: tail.data

    width: parent.width
    spacing: Config.s(10)

    Txt { text: root.icon; color: root.iconColor; font.pixelSize: root.iconSize }
    Txt {
        text: root.label; color: Theme.subtext0; font.pixelSize: Config.s(14)
        width: parent.width - x - tail.width - parent.spacing; verticalAlignment: Text.AlignVCenter
    }
    Row { id: tail }
}
