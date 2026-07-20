import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick

// eww `tray` window. Top-right, overlay layer.
// Native StatusNotifierItem host.
// Left-click: activate() unless onlyMenu. Right-click or onlyMenu: QsMenuAnchor.open().
// display() is for X11 platform menus; on Wayland use QsMenuAnchor instead.
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
            delegate: Item {
                required property var modelData
                id: iconArea
                width: root.s(18); height: root.s(18)

                QsMenuAnchor {
                    id: menuAnchor
                    menu: iconArea.modelData.menu
                    anchor.item: iconArea
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom | Edges.Right
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (m) => {
                        if (m.button === Qt.LeftButton && !iconArea.modelData.onlyMenu)
                            iconArea.modelData.activate()
                        else if (iconArea.modelData.hasMenu)
                            menuAnchor.open()
                    }
                }

                Image {
                    anchors.fill: parent
                    source: iconArea.modelData.icon
                    fillMode: Image.PreserveAspectFit
                }
            }
        }
    }
}
