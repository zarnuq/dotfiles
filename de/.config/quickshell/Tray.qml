import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick

// eww `tray` window. Top-right, overlay layer.
// Native StatusNotifierItem host (no script equivalent existed).
// Left-click activates; right-click = secondary action. Full SNI context
// menus are intentionally omitted to keep this simple.
Widget {
    id: root
    pad: 0
    bg: "transparent"
    borderColor: "transparent"
    stackLayer: WlrLayer.Overlay
    anchors { top: true; right: true }
    margins { right: s(500) }
    implicitWidth: Math.max(1, tray.width)
    implicitHeight: s(20)

    Row {
        id: tray
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.s(4)

        Repeater {
            model: SystemTray.items
            delegate: MouseArea {
                required property var modelData
                width: root.s(18); height: root.s(18)
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    if (m.button === Qt.LeftButton) modelData.activate();
                    else modelData.secondaryActivate();
                }
                Image {
                    anchors.fill: parent
                    source: parent.modelData.icon
                    fillMode: Image.PreserveAspectFit
                }
            }
        }
    }
}
