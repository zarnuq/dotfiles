import Quickshell
import QtQuick
import QtQuick.Effects

// Catppuccin-themed SNI context menu. Replaces QsMenuAnchor's native Qt
// platform menu (which ignored the theme and rendered icons as magenta/black
// "missing texture" squares). Fed by QsMenuOpener from a QsMenuHandle; renders
// entries ourselves so styling + icon loading go through Quickshell's own
// image://icon provider. Recurses for submenus via a Loader (QML forbids a
// component instantiating its own type directly).
PopupWindow {
    id: root

    // A QsMenuHandle: SystemTrayItem.menu at the top level, or a QsMenuEntry
    // (which is itself a handle) for a submenu.
    property var menuHandle: null
    // Top-most menu in the stack; leaf activation closes it (and thus every
    // child). Null on the root, where `root` itself is the top.
    property var rootMenu: null
    readonly property var top: rootMenu ? rootMenu : root

    // Caller sets wantOpen; the window only actually maps once the DBusMenu has
    // populated. QsMenuOpener loads entries asynchronously, so showing on click
    // would briefly (or, on a slow round-trip, lastingly) render an empty box —
    // that's the "blank dropdown". Gating on entryCount avoids it entirely.
    property bool wantOpen: false
    readonly property int entryCount: opener.children ? opener.children.values.length : 0

    color: "transparent"
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    visible: wantOpen && entryCount > 0
    // Only the root grabs input; the compositor's popup grab spans the whole
    // child stack and dismisses it on an outside click (river honours this).
    grabFocus: rootMenu === null

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    function close() { wantOpen = false; }

    // Closing a menu tears down any submenu it opened.
    onVisibleChanged: if (!visible && subLoader.item) subLoader.item.close()

    Rectangle {
        id: card
        color: Theme.base
        border.color: Theme.surface1
        border.width: 1
        radius: Theme.borderRadius
        implicitWidth: Math.max(170, col.implicitWidth + 2)
        implicitHeight: col.implicitHeight + 2

        Column {
            id: col
            x: 1; y: 1
            width: parent.width - 2

            Repeater {
                model: opener.children

                delegate: Item {
                    id: row
                    required property var modelData
                    width: col.width
                    height: modelData.isSeparator ? 7 : 24

                    // ---- separator ----
                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        height: 1
                        color: Theme.surface0
                    }

                    // ---- normal / checkable / submenu entry ----
                    MouseArea {
                        id: hover
                        visible: !row.modelData.isSeparator
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: row.modelData.enabled
                        onClicked: {
                            if (row.modelData.hasChildren)
                                root.toggleSub(row.modelData, row);
                            else {
                                row.modelData.triggered();
                                root.top.close();
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: hover.containsMouse ? Theme.surface0 : "transparent"
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // check mark (checkable items)
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                text: row.modelData.checkState === Qt.Checked ? "" : ""
                                color: Theme.mauve
                                font.pixelSize: 11
                                visible: row.modelData.buttonType !== 0
                            }

                            // icon (symbolic glyphs tinted to text colour so
                            // they're visible on the dark menu)
                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16
                                visible: row.modelData.icon !== ""
                                Image {
                                    id: img
                                    anchors.fill: parent
                                    source: row.modelData.icon
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.fill: parent
                                    source: img
                                    colorization: (row.modelData.icon.indexOf("symbolic") >= 0) ? 1.0 : 0.0
                                    colorizationColor: Theme.text
                                }
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.text
                                color: row.modelData.enabled ? Theme.text : Theme.surface1
                                font.pixelSize: 13
                            }
                        }

                        // submenu arrow
                        Txt {
                            visible: row.modelData.hasChildren
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            text: ""
                            color: Theme.subtext0
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    // Submenu, loaded lazily to break the compile-time self-recursion.
    Loader {
        id: subLoader
        source: "TrayMenu.qml"
        active: false
    }

    function toggleSub(handle, rowItem) {
        var m = subLoader.item;
        if (m && m.wantOpen && m.menuHandle === handle) { m.close(); return; }
        subLoader.active = true;
        m = subLoader.item;
        m.rootMenu = root.top;
        m.anchor.window = root;
        m.anchor.edges = Edges.Right | Edges.Top;
        m.anchor.gravity = Edges.Right | Edges.Bottom;
        var p = rowItem.mapToItem(null, 0, 0);
        m.anchor.rect.x = rowItem.width - 6;
        m.anchor.rect.y = p.y;
        m.anchor.rect.width = 1;
        m.anchor.rect.height = rowItem.height;
        m.menuHandle = handle;
        m.wantOpen = true;
    }
}
