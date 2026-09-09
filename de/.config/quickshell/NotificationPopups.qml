import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

// Transient notification toasts (replaces mako's popups). Top-right, overlay.
// Matches mako: 350 wide, flat, per-urgency border, auto-timeout.
PanelWindow {
    id: win

    // Show on the main screen (where the widgets live), as Widget does — this
    // had its own copy of the pin and of the scale rule, with "DP-2" written
    // out rather than read from Config.
    Component.onCompleted: {
        var target = Config.screen(Config.mainScreen)
                     || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
        if (target) win.screen = target;
    }
    property real scale: Config.scale
    function s(n) { return Config.s(n); }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    exclusiveZone: 0
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: s(10); right: s(10) }
    implicitWidth: s(350)
    implicitHeight: Math.max(1, col.implicitHeight)

    Column {
        id: col
        width: parent.width
        spacing: win.s(10)

        Repeater {
            model: NotificationService.live

            delegate: Rectangle {
                id: card
                required property var modelData
                width: col.width
                implicitHeight: content.height + win.s(24)
                color: Theme.base
                border.width: win.s(2)
                border.color: card.modelData.urgency === NotificationUrgency.Critical ? Theme.peach
                            : card.modelData.urgency === NotificationUrgency.Low ? Theme.surface1
                            : Theme.mauve

                // mako default-timeout: normal 5s, low 3s, critical 0 (stays).
                Timer {
                    interval: card.modelData.urgency === NotificationUrgency.Low ? 3000 : 5000
                    running: card.modelData.urgency !== NotificationUrgency.Critical
                    onTriggered: card.modelData.expire()
                }

                Column {
                    id: content
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: win.s(12); rightMargin: win.s(12) }
                    spacing: win.s(2)
                    Txt { text: card.modelData.appName || "Notification"; color: Theme.subtext0; font.pixelSize: win.s(15) }
                    Txt { text: card.modelData.summary; font.bold: true; font.pixelSize: win.s(20)
                          width: parent.width; wrapMode: Text.WordWrap }
                    Txt { visible: card.modelData.body !== ""; text: card.modelData.body; color: Theme.subtext0
                          font.pixelSize: win.s(18); width: parent.width; wrapMode: Text.WordWrap }
                }

                MouseArea { anchors.fill: parent; onClicked: card.modelData.dismiss() }
            }
        }
    }
}
