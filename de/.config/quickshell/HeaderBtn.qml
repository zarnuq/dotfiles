import QtQuick

// Small icon button used in widget headers (DND / clear / refresh).
// Brightens from subtext0 to text on hover; caller wires `onClicked`.
MouseArea {
    id: btn
    property string icon: ""
    property real size: 14
    property int leftMargin: 0

    implicitWidth: label.implicitWidth + leftMargin
    implicitHeight: label.implicitHeight
    hoverEnabled: true

    Txt {
        id: label
        anchors.right: parent.right
        text: btn.icon
        color: btn.containsMouse ? Theme.text : Theme.subtext0
        font.pixelSize: btn.size
    }
}
