import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

// Transient notification toasts (replaces mako's popups). Top-right, overlay.
// Matches mako: 350 wide, flat, per-urgency border, auto-timeout.
//
// This is also where the server's promises are kept. NotificationService sets
// actionsSupported/imageSupported/bodyMarkupSupported on the bus, and a
// capability we claim but never draw is worse than one we don't claim: apps
// send the buttons, the art and the markup, and nothing here could use them —
// the buttons were unreachable, the art was dropped, and the markup printed as
// literal tags.
PanelWindow {
    id: win

    // Show on the main screen (where the widgets live), as Widget does — this
    // had its own copy of the pin and of the scale rule, with "DP-2" written
    // out rather than read from Config.
    Component.onCompleted: if (Config.pinScreen) win.screen = Config.pinScreen;
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

                // The spec splits actions in two: the one keyed "default" has no
                // button and is what activating the body means, the rest are
                // buttons. Splitting once here keeps both readers off the list.
                readonly property var buttons: {
                    var out = [];
                    var a = card.modelData.actions;
                    for (var i = 0; i < a.length; i++)
                        if (a[i].identifier !== "default") out.push(a[i]);
                    return out;
                }
                readonly property var defaultAction: {
                    var a = card.modelData.actions;
                    for (var i = 0; i < a.length; i++)
                        if (a[i].identifier === "default") return a[i];
                    return null;
                }

                /// Invoke one action. A `resident` notification stays up
                /// afterwards (the spec's word for a toast you answer more than
                /// once); anything else is finished the moment you answer it.
                function run(action) {
                    action.invoke();
                    if (!card.modelData.resident) card.modelData.dismiss();
                }

                // mako default-timeout: normal 5s, low 3s, critical 0 (stays).
                Timer {
                    interval: card.modelData.urgency === NotificationUrgency.Low ? 3000 : 5000
                    running: card.modelData.urgency !== NotificationUrgency.Critical
                    onTriggered: card.modelData.expire()
                }

                // Declared BEFORE the content, so the action buttons' own
                // MouseAreas sit above it — z-order follows declaration order,
                // and this one covers the whole card.
                MouseArea {
                    anchors.fill: parent
                    onClicked: card.defaultAction ? card.run(card.defaultAction)
                                                  : card.modelData.dismiss()
                }

                Column {
                    id: content
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: win.s(12); rightMargin: win.s(12) }
                    spacing: win.s(6)

                    Row {
                        id: head
                        width: parent.width
                        spacing: img.visible ? win.s(10) : 0

                        Image {
                            id: img
                            source: card.modelData.image
                            visible: card.modelData.image !== ""
                            width: visible ? win.s(48) : 0
                            height: visible ? win.s(48) : 0
                            // Under QT_QUICK_BACKEND=software every pixel is
                            // decoded and scaled on the CPU, and `image` is
                            // whatever path the app handed over — a full-size
                            // cover or avatar. Cap the decode at the drawn size.
                            sourceSize.width: win.s(48)
                            sourceSize.height: win.s(48)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Column {
                            width: head.width - img.width - head.spacing
                            spacing: win.s(2)
                            Txt { text: card.modelData.appName || "Notification"; color: Theme.subtext0; font.pixelSize: win.s(15) }
                            Txt { text: card.modelData.summary; font.bold: true; font.pixelSize: win.s(20)
                                  width: parent.width; wrapMode: Text.WordWrap }
                            Txt {
                                visible: card.modelData.body !== ""
                                text: card.modelData.body
                                color: Theme.subtext0
                                font.pixelSize: win.s(18)
                                width: parent.width
                                wrapMode: Text.WordWrap
                                // The server claims bodyMarkupSupported, so a body
                                // may carry the spec's small HTML subset (<b> <i>
                                // <u> <a> <img>). Txt defaults to PlainText, which
                                // printed those tags verbatim. StyledText is that
                                // subset exactly; RichText is a whole HTML engine
                                // for no gain and more CPU under the software
                                // backend.
                                textFormat: Text.StyledText
                                linkColor: Theme.blue
                                onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
                            }
                        }
                    }

                    Row {
                        id: actionRow
                        visible: card.buttons.length > 0
                        width: parent.width
                        spacing: win.s(6)

                        Repeater {
                            model: card.buttons

                            delegate: Rectangle {
                                id: btn
                                required property var modelData
                                width: (actionRow.width - (card.buttons.length - 1) * actionRow.spacing)
                                       / card.buttons.length
                                height: win.s(28)
                                color: hover.containsMouse ? Theme.surface1 : Theme.surface0

                                Txt {
                                    anchors.centerIn: parent
                                    width: parent.width - win.s(12)
                                    text: btn.modelData.text
                                    font.pixelSize: win.s(15)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: hover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: card.run(btn.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
