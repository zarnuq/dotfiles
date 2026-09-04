import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Bottom-right: charge level + state. Reads /sys/class/power_supply/BAT0
// directly on a 10s timer — upowerd is not running on this box, so
// Quickshell.Services.UPower would report nothing.
//
// Below `lowAt` while discharging the readout turns red and one critical
// notification is raised. The warning is latched and only re-arms once the
// level climbs back over `clearAt` (or a charger is plugged in), so a charge
// hovering on the threshold can't spam the toast.
//
// Sits bottom-right rather than in the packed left column: nothing else lives
// there, and on the desktop (no BAT0) the card hides itself without leaving a
// hole in a stack of anchored margins.
//
// Layer is state-dependent. At rest it is Bottom like the other ambient cards,
// i.e. wallpaper furniture that any tiled window covers. Once low it jumps to
// Overlay so the red readout stays visible over a full-screen terminal — the
// one moment the card has to be seen is the one moment a Bottom layer hides it.
Widget {
    id: root

    anchors { bottom: true; right: true }
    implicitWidth: s(300)
    implicitHeight: s(75)

    visible: present
    borderColor: low ? Theme.red : Theme.surface0
    stackLayer: low ? WlrLayer.Overlay : WlrLayer.Bottom

    readonly property string dir: "/sys/class/power_supply/BAT0"
    readonly property int lowAt: 20      // warn below this
    readonly property int clearAt: 25    // re-arm the warning above this

    property bool present: false
    property int level: 100
    property string status: "Unknown"
    property bool warned: false

    readonly property bool charging: status === "Charging" || status === "Full"
    readonly property bool low: present && !charging && level < lowAt
    readonly property color tint: low ? Theme.red : charging ? Theme.green : Theme.text

    FileView { id: capFile;  path: root.dir + "/capacity"; blockLoading: true }
    FileView { id: statFile; path: root.dir + "/status";   blockLoading: true }

    function poll() {
        capFile.reload();
        statFile.reload();

        // Missing/unreadable battery reads back empty — treat as "no battery"
        // rather than letting Number("") land us on a fake 0%.
        var cap = capFile.text().trim();
        if (cap.length === 0 || isNaN(Number(cap))) { root.present = false; return; }

        root.present = true;
        root.level = Number(cap);
        root.status = statFile.text().trim();

        if (root.low && !root.warned) {
            root.warned = true;
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "battery",
                                     "Battery low",
                                     root.level + "% remaining — plug in."]);
        } else if (root.warned && (root.charging || root.level >= root.clearAt)) {
            root.warned = false;
        }
    }

    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.poll() }

    Column {
        anchors.fill: parent
        spacing: root.s(8)

        Row {
            width: parent.width
            spacing: root.s(10)
            Txt {
                text: root.charging ? "󰂄" : root.low ? "󰂃" : "󰁹"
                color: root.tint
                font.pixelSize: root.s(18)
            }
            Txt {
                text: root.charging ? "charging" : "battery"
                color: Theme.subtext0; font.pixelSize: root.s(14)
                width: parent.width - x - value.width - parent.spacing
                verticalAlignment: Text.AlignVCenter
            }
            Txt { id: value; text: root.level + "%"; color: root.tint; font.pixelSize: root.s(14) }
        }

        // Flat gauge, same shape as the brightness slider but read-only.
        Rectangle {
            width: parent.width
            height: root.s(8)
            color: Theme.surface0
            Rectangle {
                height: parent.height
                width: parent.width * root.level / 100
                color: root.tint
            }
        }
    }
}
