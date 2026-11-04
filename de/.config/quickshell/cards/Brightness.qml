pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Top of the left bar's lower stack: sits directly under the clock (150 tall),
// so the calendar below it can stretch into whatever is left. 420x130.
//
// Two sliders: brightness over night-light temperature. Both values arrive from
// reach's state socket through the Reach singleton (no poll). The socket is
// write-only, so a drag sets a value the way every reach setting is set: it
// writes one small file in ~/.config/reach (reach merges every *.zon there) and
// SIGHUPs it. `brightness.zon` holds `.gamma.brightness`, which reach applies only
// when a reload CHANGES it, so Super+Alt+Left/Right keep stepping from there;
// `nightlight.zon` holds `.gamma.temperature`. Both files are per-machine state
// (gitignored), and written on release only — one reload per gesture.
Widget {
    id: root
    anchors { top: true; left: true }
    margins { top: s(150) }
    implicitWidth: s(420)
    implicitHeight: s(130)

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/reach"

    // Atomic write (tmp + mv, so a reload never reads half a file), then reload.
    function write(file, zon): void {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" > "$2.tmp" && mv "$2.tmp" "$2" && pkill -HUP -x reach',
                                 "sh", zon, root.dir + "/" + file]);
    }

    Column {
        anchors.fill: parent
        spacing: root.s(6)

        // 10 is reach's floor (a keybind must never be able to black the screen
        // out), so the bar measures the 10..100 range rather than 0..100.
        // ponytail: dragging back to the exact value brightness.zon already holds
        // is no change to reach, so it is ignored; nudge it a step off and back.
        Slider {
            icon: "󰃟"; label: "brightness"; color: Theme.yellow
            from: 10; to: 100; stepSize: 1
            live: Reach.brightness
            text: value + "%"
            onCommitted: v => root.write("brightness.zon", ".{ .gamma = .{ .brightness = " + v + " } }")
        }

        // Warm on the left, like the sun going down.
        Slider {
            icon: "󰖔"; label: "night light"; color: Theme.peach
            from: 2500; to: 6500; stepSize: 100
            live: Reach.temperature
            text: value >= 6500 ? "off" : value + "K"
            onCommitted: v => root.write("nightlight.zon", ".{ .gamma = .{ .temperature = " + v + " } }")
        }
    }

    // A header row over a draggable gauge. Shows `live` (what reach reports)
    // except mid-drag, when it shows where the pointer is.
    component Slider: Column {
        id: sl
        property string icon
        property string label
        property color color
        property string text
        property int from
        property int to
        property int stepSize
        property int live
        property int dragged: -1
        readonly property int value: dragged >= 0 ? dragged : live
        signal committed(int v)

        width: parent.width
        spacing: root.s(4)

        CardHeader {
            icon: sl.icon; iconColor: sl.color; label: sl.label
            Txt { text: sl.text; font.pixelSize: root.s(14) }
        }

        // Flat gauge, centred in a taller strip that is also the grab area.
        Item {
            width: parent.width
            height: root.s(16)

            Gauge {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                fraction: (sl.value - sl.from) / (sl.to - sl.from)
                fillColor: sl.color
                animated: sl.dragged < 0
            }

            MouseArea {
                anchors.fill: parent
                onPressed: e => sl.dragged = at(e.x)
                onPositionChanged: e => { if (pressed) sl.dragged = at(e.x); }
                onReleased: {
                    if (sl.dragged !== sl.live) sl.committed(sl.dragged);
                    sl.dragged = -1;
                }
                function at(x) {
                    var f = Math.max(0, Math.min(1, x / track.width));
                    return sl.from + Math.round(f * (sl.to - sl.from) / sl.stepSize) * sl.stepSize;
                }
            }
        }
    }
}
