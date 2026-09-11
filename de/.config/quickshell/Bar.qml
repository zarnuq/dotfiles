import Quickshell
import Quickshell.Wayland
import QtQuick

// The status bar, one per output — replacing the one reach drew itself.
//
// Layout is deliberately the same as reach's baked-in bar (src/bar.zig), so the
// switch is invisible:
//
//   [desktops] [ title .......... app_id ] [ status ]
//
// Desktops hide when vacant, and the viewed one takes the `select` scheme.
// An occupied desktop is indicated by its visible cell. The title region carries the
// select scheme on the FOCUSED output only — that is the "this monitor is
// active" cue, and it is the whole reason the bar needs window-manager state at
// all. That state comes from Reach.qml (reach's socket); everything on the
// right is read natively here, which is what retires the six block scripts in
// ~/.config/reach/blocks and the `kill -35/-36` refresh binds with them.
//
// EXCLUSIVE ZONE: unlike reach's bar (a river shell surface, which reach had to
// subtract from the layout by hand) this is an ordinary layer surface, so the
// compositor reserves the strip for us — windows and the other quickshell cards
// are pushed below it with no window-manager involvement.
Scope {
    id: root

    function s(n) { return Config.s(n); }

    readonly property int fontSize: s(15)

    // The bar is exactly its text's line box — no padding at all. A fixed height
    // (26px, as it started) left several pixels of dead base colour above and
    // below the glyphs. metrics.height is the floor here, not a starting point:
    // it is ascent + descent, so anything less clips descenders and the taller
    // Nerd Font icons.
    FontMetrics {
        id: metrics
        font.family: Theme.font
        font.pixelSize: root.fontSize
    }
    readonly property int barHeight: Math.ceil(metrics.height)

    // Tray icons sit in the status row, so they are sized off the bar, not
    // off a fixed pixel count — they have to shrink with it, not overflow it.
    readonly property int trayIconSize: root.barHeight - root.s(6)

    // reach's bar colours (config.zon `.bar`), so the two look identical.
    readonly property color normalFg: "#7f849c"
    readonly property color selectFg: "#ffffff"
    readonly property color selectBg: Theme.mauve

    // ─── status sources ──────────────────────────────────────────────────
    // Shared by every output's bar: sampled once here, not once per monitor.

    BarStatusData { id: sharedStatus }

    // ─── the bars ────────────────────────────────────────────────────────

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData

            // reach's state for THIS monitor. Null until the socket delivers its
            // first snapshot, which is also what a reach without the ipc patch
            // looks like — the status side still works, so the bar degrades to a
            // clock rather than to nothing.
            readonly property var wm: Reach.forScreen(modelData.name)

            screen: modelData
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: root.barHeight
            exclusiveZone: root.barHeight
            color: Theme.base
            WlrLayershell.layer: WlrLayer.Top

            // A fullscreen window owns the output, exactly as in reach's bar.
            // Hiding the surface releases the exclusive zone with it, so the
            // window really does get the whole screen.
            visible: !(wm && wm.fullscreen)

            // 1. Desktop cells. Shown only if viewed or occupied (dwlb's
            //    hide_vacant), so the row is as short as the session is busy.
            //    Occupancy gets no marker of its own — the cell being there at
            //    all already says it, and reach's corner box just added noise.
            Row {
                id: desktops
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }

                Repeater {
                    model: Reach.desktops

                    Rectangle {
                        required property int index

                        readonly property int desktop: index + 1
                        readonly property bool active: bar.wm ? bar.wm.desktop === desktop : false
                        readonly property bool occupied: bar.wm ? bar.wm.occupied.indexOf(desktop) !== -1 : false
                        readonly property color fg: active ? root.selectFg : root.normalFg

                        visible: active || occupied
                        width: visible ? label.implicitWidth + root.s(13) : 0
                        height: parent.height
                        color: active ? root.selectBg : Theme.base

                        Txt {
                            id: label
                            anchors.centerIn: parent
                            text: parent.desktop
                            color: parent.fg
                            font.pixelSize: root.fontSize
                        }
                    }
                }
            }

            // 3. Status, right-aligned. Blocks in reach's config.zon order,
            //    joined by the same "|" delimiter.
            BarStatus {
                id: status
                statusData: sharedStatus
                panelWindow: bar
                fontSize: root.fontSize
                trayIconSize: root.trayIconSize
                normalFg: root.normalFg
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    rightMargin: root.s(6)
                }
            }

            // 2. Title region: everything between the desktops and the status.
            //    Drawn last so its background can't paint over either.
            Rectangle {
                anchors {
                    left: desktops.right
                    right: status.left
                    top: parent.top
                    bottom: parent.bottom
                }
                color: (bar.wm && bar.wm.focused) ? root.selectBg : Theme.base

                readonly property color fg: (bar.wm && bar.wm.focused) ? root.selectFg : root.normalFg

                Txt {
                    anchors {
                        left: parent.left
                        right: appId.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: root.s(6)
                        rightMargin: root.s(10)
                    }
                    text: bar.wm ? bar.wm.title : ""
                    color: parent.fg
                    font.pixelSize: root.fontSize
                    elide: Text.ElideRight
                }

                // The focused window's app_id, right-aligned — it is the match
                // key for a window rule, so having it on screen is what makes
                // writing one a glance rather than a hunt.
                Txt {
                    id: appId
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: root.s(6)
                    }
                    text: bar.wm ? bar.wm.appId : ""
                    color: parent.fg
                    font.pixelSize: root.fontSize
                }
            }
        }
    }
}
