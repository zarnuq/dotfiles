pragma ComponentBehavior: Bound
import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Sys, Volume,
// Reach, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

// Small icon button used in widget headers (DND / clear / refresh) and, with
// `centered`, for Mpd's transport row. Brightens from subtext0 to text on
// hover; caller wires `onClicked`.
MouseArea {
    id: root
    property string icon: ""
    property real size: 14
    property int leftMargin: 0
    // Header buttons pin the icon right, so `leftMargin` opens a gap before
    // it; a button given a size of its own (Mpd's) centres it instead.
    property bool centered: false

    implicitWidth: label.implicitWidth + leftMargin
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
