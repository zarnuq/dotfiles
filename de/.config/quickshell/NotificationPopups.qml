pragma ComponentBehavior: Bound
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
    id: root

    // Show on the main screen (where the widgets live), as Widget does — this
    // had its own copy of the pin and of the scale rule, with "DP-2" written
    // out rather than read from Config.
    Component.onCompleted: if (Config.pinScreen) root.screen = Config.pinScreen;
    function s(n) { return Config.s(n); }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    exclusiveZone: 0
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: s(10); right: s(10) }
    implicitWidth: s(350)
    // The stack scrolls a whole card per wheel notch, and the window is sized
    // to the whole cards that fit under `cap` from `top` down, so the bottom
    // edge never cuts a card in half. Long bodies are capped (maximumLineCount
    // below) so one card can't outgrow the cap; the full text is in the
    // Notifications menu.
    readonly property real cap: (root.screen ? root.screen.height : 1080) / 2
    property int first: 0
    // `first` can outlive the cards above it expiring; clamp on read.
    readonly property int top: Math.max(0, Math.min(root.first, rep.count - 1))

    // How many whole cards from `top` fit under the cap, and their height.
    function fit(): var {
        let h = 0, n = 0;
        for (let i = root.top; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (!it) break;
            const next = h + (h > 0 ? col.spacing : 0) + it.height;
            if (next > root.cap && n > 0) break;
            h = next;
            n++;
        }
        return { h: Math.min(h, root.cap), n: n };
    }
    readonly property var fitted: col.implicitHeight >= 0 ? fit() : { h: 0, n: 0 }
    readonly property int below: rep.count - root.top - root.fitted.n
    readonly property bool scrolls: root.top > 0 || root.below > 0
    // The surface stays at full height while anything is up, so a scroll only
    // animates items (resizing a layer surface every frame would be a
    // configure round-trip per frame). The input mask keeps the transparent
    // part below the cards click-through.
    implicitHeight: rep.count ? root.cap + more.height + root.s(4) : 1
    mask: Region { item: hit }

    // Scroll motion: the stack slides and the visible area resizes together,
    // then settles on whole cards.
    readonly property int slideMs: 160

    // Called from the cards' own MouseAreas: a MouseArea takes every wheel
    // event over it, so a WheelHandler behind the cards never saw one.
    // A mouse notch (a multiple of 120) moves one card. A touchpad sends a
    // stream of small deltas that piled up to several cards per swipe, so it
    // needs `touchpadStep` of travel per card; raise it to scroll slower.
    readonly property int touchpadStep: 400
    property real wheelAcc: 0
    function wheel(dy): void {
        if (dy * root.wheelAcc < 0) root.wheelAcc = 0;   // direction change
        root.wheelAcc += dy;
        const step = dy % 120 === 0 ? 120 : root.touchpadStep;
        if (root.wheelAcc >= step) root.first = Math.max(0, root.top - 1);
        else if (root.wheelAcc <= -step) root.first = Math.min(rep.count - 1, root.top + 1);
        else return;
        root.wheelAcc = 0;
    }

    Txt {
        id: more
        visible: root.scrolls
        anchors { right: parent.right; top: view.bottom; topMargin: root.s(4) }
        text: (root.top > 0 ? "↑ " + root.top : "") + (root.top > 0 && root.below > 0 ? "   " : "")
              + (root.below > 0 ? "↓ " + root.below : "")
        color: Theme.subtext0
        font.pixelSize: root.s(15)
        MouseArea { anchors.fill: parent; onWheel: e => root.wheel(e.angleDelta.y) }
    }

    Item {
        id: hit
        width: parent.width
        height: view.height + (root.scrolls ? more.height + root.s(4) : 0)
    }

    Item {
        id: view
        width: parent.width
        height: root.fitted.h
        clip: true
        Behavior on height { NumberAnimation { duration: root.slideMs; easing.type: Easing.OutCubic } }

        Column {
            id: col
            width: root.width
            y: rep.count && rep.itemAt(root.top) ? -rep.itemAt(root.top).y : 0
            Behavior on y { NumberAnimation { duration: root.slideMs; easing.type: Easing.OutCubic } }
            spacing: root.s(10)

            Repeater {
                id: rep
                model: NotificationService.live

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    width: col.width
                    implicitHeight: content.height + root.s(24)
                    color: Theme.base
                    border.width: root.s(2)
                    border.color: card.modelData.urgency === NotificationUrgency.Critical ? Theme.peach
                                : card.modelData.urgency === NotificationUrgency.Low ? Theme.surface1
                                : Theme.mauve

                    // The spec splits actions in two: the one keyed "default" has no
                    // button and is what activating the body means, the rest are
                    // buttons. Splitting once here keeps both readers off the list.
                    readonly property var buttons: card.modelData.actions.filter(a => a.identifier !== "default")
                    readonly property var defaultAction: card.modelData.actions.find(a => a.identifier === "default") || null

                    // An action is just invoke(): a `resident` notification stays up
                    // afterwards, anything else is finished the moment you answer it,
                    // and invoke() does that closing itself (Quickshell's
                    // NotificationAction::invoke closes a non-resident notification
                    // after sending ActionInvoked) — a dismiss() as well would be a
                    // second close on a destroyed object, logged as
                    // "Cannot close destroyed notification".

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
                        onWheel: e => root.wheel(e.angleDelta.y)
                        onClicked: card.defaultAction ? card.defaultAction.invoke()
                                                      : card.modelData.dismiss()
                    }

                    Column {
                        id: content
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                  leftMargin: root.s(12); rightMargin: root.s(12) }
                        spacing: root.s(6)

                        Row {
                            id: head
                            width: parent.width
                            spacing: img.visible ? root.s(10) : 0

                            Image {
                                id: img
                                source: card.modelData.image
                                visible: card.modelData.image !== ""
                                width: visible ? root.s(48) : 0
                                height: visible ? root.s(48) : 0
                                // Under QT_QUICK_BACKEND=software every pixel is
                                // decoded and scaled on the CPU, and `image` is
                                // whatever path the app handed over — a full-size
                                // cover or avatar. Cap the decode at the drawn size.
                                sourceSize.width: root.s(48)
                                sourceSize.height: root.s(48)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Column {
                                width: head.width - img.width - head.spacing
                                spacing: root.s(2)
                                Txt { text: card.modelData.appName || "Notification"; color: Theme.subtext0; font.pixelSize: root.s(15) }
                                Txt { text: card.modelData.summary; font.bold: true; font.pixelSize: root.s(20)
                                      width: parent.width; wrapMode: Text.WordWrap }
                                Txt {
                                    visible: card.modelData.body !== ""
                                    text: card.modelData.body
                                    color: Theme.subtext0
                                    font.pixelSize: root.s(18)
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 8
                                    elide: Text.ElideRight
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
                            spacing: root.s(6)

                            Repeater {
                                model: card.buttons

                                delegate: Rectangle {
                                    id: btn
                                    required property var modelData
                                    width: (actionRow.width - (card.buttons.length - 1) * actionRow.spacing)
                                           / card.buttons.length
                                    height: root.s(28)
                                    color: hover.containsMouse ? Theme.surface1 : Theme.surface0

                                    Txt {
                                        anchors.centerIn: parent
                                        width: parent.width - root.s(12)
                                        text: btn.modelData.text
                                        font.pixelSize: root.s(15)
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: hover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: btn.modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
