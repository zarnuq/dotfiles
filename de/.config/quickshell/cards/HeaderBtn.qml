pragma ComponentBehavior: Bound
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Small icon button used in widget headers (DND / clear / refresh) and, with
// `centered`, for Mpd's transport row. Brightens from subtext0 to text on
// hover; caller wires `onClicked`.
MouseArea {
    id: root
    property string icon: ""
    property real size: Config.s(14)
    // Header buttons are exactly as wide as their icon; a button given a size
    // of its own (Mpd's) centres the icon in it instead.
    property bool centered: false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    hoverEnabled: true

    Txt {
        id: label
        anchors.right: root.centered ? undefined : parent.right
        anchors.centerIn: root.centered ? parent : undefined
        text: root.icon
        color: root.containsMouse ? Theme.text : Theme.subtext0
        font.pixelSize: root.size
    }
}
