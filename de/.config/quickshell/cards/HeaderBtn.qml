import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Sys, Volume,
// Reach, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

// Small icon button used in widget headers (DND / clear / refresh) and, with
// `centered`, for Mpd's transport row. Brightens from subtext0 to text on
// hover; caller wires `onClicked`.
MouseArea {
    id: btn
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
        anchors.right: btn.centered ? undefined : parent.right
        anchors.centerIn: btn.centered ? parent : undefined
        text: btn.icon
        color: btn.containsMouse ? Theme.text : Theme.subtext0
        font.pixelSize: btn.size
    }
}
