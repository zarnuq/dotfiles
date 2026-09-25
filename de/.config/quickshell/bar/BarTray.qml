pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Reach, Sys,
// Volume, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

// Each output owns its icons and menu so clicks anchor to that output's bar.
Row {
    id: root

    required property int iconSize

    spacing: Config.s(4)
    rightPadding: Config.s(8)
    visible: Config.on("tray") && SystemTray.items.values.length > 0

    TrayMenu {
        id: menu
        // The bar this row sits in, found through the window attached
        // property rather than handed down through BarStatus.
        anchor.window: root.QsWindow.window
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom | Edges.Left

        function openFor(item, iconItem): void {
            // Clicking the same icon again also closes a still-loading menu.
            if (menu.wantOpen && menu.menuHandle === item.menu) {
                menu.close();
                return;
            }
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

    Repeater {
        model: SystemTray.items

        Item {
            id: iconArea
            required property var modelData

            width: root.iconSize
            height: root.iconSize

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: m => {
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
                sourceSize.width: root.iconSize
                sourceSize.height: root.iconSize
                fillMode: Image.PreserveAspectFit
            }
        }
    }
}
