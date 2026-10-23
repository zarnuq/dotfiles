pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// Laptop power menu (Super+R p / `qs ipc call powermode toggle`): three CPU/power
// profiles plus a HARDWARE backlight slider. The backlight (amdgpu_bl0) is the
// real power lever and is deliberately separate from reach's gamma dimming
// (Super+Alt+Left/Right), which only reshapes the ramp and saves nothing.
//
// Modes go through the PowerProfile singleton (optimistic + OSD). Everything runs
// user-level via ~/.local/bin/powermode + /etc/udev/rules.d/99-powermode.rules.
Picker {
    id: root

    ipcTarget: "powermode"

    readonly property var modes: [
        { kind: "mode", id: "performance", icon: "󰓅", label: "Performance", desc: "max clocks, boost" },
        { kind: "mode", id: "balanced",    icon: "󰾅", label: "Balanced",    desc: "default" },
        { kind: "mode", id: "saver",       icon: "󰌪", label: "Power saver", desc: "2 GHz cap, no boost" }
    ]

    // Brightness row first, then the modes.
    rows: [{ kind: "bright" }].concat(root.modes)
    rowHeight: s(40)
    barHeight: s(30)
    minBoxHeight: s(190)
    boxWidth: s(380)

    // ---- backlight ----
    property int brightPct: 100

    Poll {
        id: blGet
        running: false
        command: [PowerProfile.script, "bl", "get"]
        onData: d => root.brightPct = parseInt((d || "").trim()) || root.brightPct
    }
    Process { id: blSet }

    // Throttle writes: a drag emits one move per frame, each a sysfs write + a
    // process spawn. Leading write, then one trailing flush per 50ms.
    Timer {
        id: blThrottle
        interval: 50
        property int pending: -1
        onTriggered: {
            if (blThrottle.pending < 0 || blSet.running) return;
            blSet.command = [PowerProfile.script, "bl", "set", "" + blThrottle.pending];
            blSet.running = true;
            blThrottle.pending = -1;
        }
    }

    function setBright(pct): void {
        var p = Math.max(1, Math.min(100, Math.round(pct)));
        root.brightPct = p;
        blThrottle.pending = p;
        if (!blThrottle.running) blThrottle.start();
    }

    onOpenChanged: if (open) { PowerProfile.refresh(); blGet.refresh(); }

    // Keyboard Enter routes here (Picker.navKey → activate(selected)); click goes
    // through the delegate's onActivated. Only mode rows apply; the slider ignores it.
    function activate(i): void {
        if (!selectable(i) || rows[i].kind !== "mode") return;
        PowerProfile.apply(rows[i].id);
        root.hide();
    }

    box: Component {
        PickerList {
            picker: root
            hint: "enter apply · ←/→ brightness"

            // Brightness via the keyboard: Left/Right (or h/l) step it while the
            // brightness row is selected. navKey only claims Up/Down/j/k, so these
            // are free. (The on-row drag is blocked by PickerHover, so keys are the
            // reliable path.)
            onExtraKey: function (e) {
                if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return;
                if (root.rows[root.selected].kind !== "bright") return;
                if (e.key === Qt.Key_Left || e.key === Qt.Key_H) root.setBright(root.brightPct - 5);
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) root.setBright(root.brightPct + 5);
                else return;
                e.accepted = true;
            }

            rowDelegate: PickerRow {
                id: rowItem
                readonly property bool isBright: rowItem.modelData.kind === "bright"

                picker: root
                width: parent.width
                current: !rowItem.isBright && rowItem.modelData.id === PowerProfile.mode
                onActivated: root.activate(rowItem.index)

                icon: rowItem.isBright ? "󰃠" : rowItem.modelData.icon
                label: rowItem.isBright ? "Brightness" : rowItem.modelData.label
                trailing: rowItem.isBright ? root.brightPct + "%" : rowItem.modelData.desc
                trailingWidth: root.s(140)
                trailingColor: rowItem.isBright ? Theme.subtext0 : Theme.overlay0
                slotWidth: rowItem.isBright ? root.s(150) : 0

                // Backlight slider — drag anywhere on the track to set it.
                Gauge {
                    id: track
                    visible: rowItem.isBright
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: root.s(6)
                    fraction: Math.max(0, Math.min(1, root.brightPct / 100))
                    fillColor: rowItem.sel ? Theme.mauve : Theme.surface1

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -root.s(10)
                        enabled: rowItem.isBright
                        onPressed: e => { root.selected = rowItem.index; root.setBright((e.x - root.s(10)) / track.width * 100); }
                        onPositionChanged: e => { if (pressed) root.setBright((e.x - root.s(10)) / track.width * 100); }
                    }
                }
            }
        }
    }
}
