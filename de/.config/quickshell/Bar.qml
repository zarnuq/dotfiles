import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick

// The status bar, one per output — replacing the one reach drew itself.
//
// Layout is deliberately the same as reach's baked-in bar (src/bar.zig), so the
// switch is invisible:
//
//   [desktops] [ title .......... app_id ] [ status ]
//
// Desktops hide when vacant, the viewed one takes the `select` scheme, and an
// occupied one gets the little corner box. The title region carries the
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

    readonly property real scale: Config.scale
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

    property string clock: ""
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // date '+%a %m/%d %I:%M %p'
            var d = new Date();
            var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            var h12 = d.getHours() % 12;
            if (h12 === 0)
                h12 = 12;
            root.clock = days[d.getDay()] + " " + p2(d.getMonth() + 1) + "/" + p2(d.getDate()) + " " + p2(h12) + ":" + p2(d.getMinutes()) + " " + (d.getHours() < 12 ? "AM" : "PM");
        }
    }
    function p2(n) {
        return ("" + n).padStart(2, "0");
    }

    // Volume, mic and the sink name come from the Volume singleton — this is
    // what `pactl get-sink-volume` at 1 Hz plus audio.sh's `pactl list sinks |
    // awk | sed` pipeline were doing.
    //
    // audio.sh's sed, ported: drop the parenthetical, then the boilerplate words
    // that every ALSA description carries, then squeeze the leftover spaces.
    readonly property string sinkName: {
        var d = Volume.sinkName;
        return d.replace(/\([^)]*\)/g, "").replace(/\b(Analog|HD|Audio|17h|19h|1ah|Digital|Stereo|Mono|Controller|Family|Surround|Sink|Output|A2DP|Pro|Profile|HDMI)\b/gi, "").replace(/\//g, "").replace(/ +/g, " ").trim();
    }

    // ip.sh: the address of whatever interface owns the default route.
    property string ip: "no link"
    Poll {
        command: ["sh", "-c", "iface=$(ip route show default 2>/dev/null | awk '/default/ { print $5; exit }'); " + "[ -z \"$iface\" ] && { echo 'no link'; exit; }; " + "addr=$(ip -4 addr show \"$iface\" | awk '/inet / { print $2 }' | cut -d/ -f1); " + "[ -z \"$addr\" ] && { echo 'no ip'; exit; }; echo \" $iface: $addr\""]
        interval: 30000
        onData: text => root.ip = text.trim()
    }

    // battery.sh's glyph ladder. The reading behind it is Sys's now — the card
    // in the corner wants the same two sysfs files, and there was no reason for
    // two timers over them at two different intervals.
    readonly property string batteryGlyph: {
        if (Sys.batteryStatus === "Charging")
            return "";
        if (Sys.batteryStatus !== "Discharging")
            return "";
        if (Sys.batteryLevel <= 10)
            return "";
        if (Sys.batteryLevel <= 25)
            return "";
        if (Sys.batteryLevel <= 50)
            return "";
        if (Sys.batteryLevel <= 75)
            return "";
        return "";
    }

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

            // One themed context menu per bar, retargeted to whichever tray icon
            // was clicked. Anchored to this window, so it drops from the bar on
            // the output the click happened on.
            TrayMenu {
                id: menu
                anchor.window: bar
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom | Edges.Left

                function openFor(item, iconItem) {
                    // Clicking the same icon again closes the (possibly still
                    // loading) menu.
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
            Row {
                id: status
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    rightMargin: root.s(6)
                }
                spacing: 0
                // The title region is anchored to this row's left edge, so without
                // padding here the first status block starts exactly where the
                // mauve ends and "kitty" runs straight into "wlp2s0". Padding the
                // row instead of the first block keeps the gap whether the tray is
                // showing or hidden.
                leftPadding: root.s(8)

                component Block: Txt {
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    color: root.normalFg
                    font.pixelSize: root.fontSize
                }
                component Delim: Block {
                    text: "|"
                }

                // System tray, at the head of the status row — the first thing
                // right of the title region's app_id. It used to be its own
                // overlay-layer window floating at top-center (Tray.qml); in the
                // bar it needs no window of its own.
                Row {
                    id: tray
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.s(4)
                    rightPadding: root.s(8)
                    visible: Config.on("tray") && SystemTray.items.values.length > 0

                    Repeater {
                        model: SystemTray.items

                        Item {
                            id: iconArea
                            required property var modelData

                            width: root.trayIconSize
                            height: root.trayIconSize

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
                                sourceSize.width: root.trayIconSize
                                sourceSize.height: root.trayIconSize
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                    }
                }
                // Padded on both sides, unlike the tight delimiters between the
                // text blocks: an icon crowded against a pipe that is itself
                // crowded against "wlp2s0" reads as one run-on clump, where text
                // blocks of similar weight don't.
                Delim {
                    visible: tray.visible
                    rightPadding: root.s(8)
                }

                Block {
                    text: root.ip
                }
                Delim {}
                Block {
                    text: root.sinkName
                    visible: text.length > 0
                }
                Delim {
                    visible: root.sinkName.length > 0
                }
                Block {
                    text: Volume.volume + "%"
                }
                Delim {}
                // mic.sh flags an UNMUTED mic red — the warning is that the room
                // is being heard, so muted is the quiet state.
                Block {
                    text: Volume.micVolume + "%"
                    color: Volume.micMuted ? root.normalFg : Theme.red
                }
                Delim {}
                Block {
                    text: root.clock
                }
                Delim {
                    visible: Sys.batteryPresent
                }
                Block {
                    visible: Sys.batteryPresent
                    text: root.batteryGlyph + " " + Sys.batteryLevel + "%"
                    color: Sys.charging ? Theme.green : (Sys.batteryLevel < 20 ? Theme.red : root.normalFg)
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
