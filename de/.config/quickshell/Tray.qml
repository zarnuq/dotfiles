import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick

// eww `tray` window. Top-right, overlay layer.
// Native StatusNotifierItem host.
// Left- or right-click opens the item's context menu (our own themed TrayMenu,
// not the native Qt platform menu). Items with no menu fall back to activate().
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

    // One shared menu popup, retargeted to whichever icon was clicked.
    TrayMenu {
        id: menu
        anchor.window: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom | Edges.Left

        function openFor(item, iconItem) {
            // Clicking the same icon again closes the (possibly still-loading) menu.
            if (menu.wantOpen && menu.menuHandle === item.menu) { menu.close(); return; }
            menu.wantOpen = false;
            menu.menuHandle = item.menu;
            var p = iconItem.mapToItem(null, 0, 0);
            menu.anchor.rect.x = p.x;
            menu.anchor.rect.y = p.y + iconItem.height;
            menu.anchor.rect.width = iconItem.width;
            menu.anchor.rect.height = 1;
            menu.wantOpen = true;
        }
    }

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

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: (m) => {
                        if (m.button === Qt.MiddleButton) {
                            iconArea.modelData.secondaryActivate();
                        } else if (iconArea.modelData.hasMenu) {
                            menu.openFor(iconArea.modelData, iconArea);
                        } else if (!iconArea.modelData.onlyMenu) {
                            iconArea.modelData.activate();
                        }
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
