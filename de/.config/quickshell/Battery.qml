import Quickshell
import Quickshell.Wayland
import QtQuick

// Bottom-right: charge level + state, read from Sys (which owns the BAT0 sysfs
// poll, since the bar's battery block needs the same two files).
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

    readonly property int lowAt: 20      // warn below this
    readonly property int clearAt: 25    // re-arm the warning above this

    // The reading is Sys's — the bar's battery block wants the same two sysfs
    // files. What stays here is the part that is this card's: the tint, and the
    // latch that keeps one toast from firing over and over on the threshold.
    readonly property bool present: Sys.batteryPresent
    readonly property int level: Sys.batteryLevel
    readonly property bool charging: Sys.charging
    readonly property bool low: present && !charging && level < lowAt
    readonly property color tint: low ? Theme.red : charging ? Theme.green : Theme.text

    property bool warned: false

    onLowChanged: root.warn()
    onChargingChanged: root.warn()

    function warn() {
        if (root.low && !root.warned) {
            root.warned = true;
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "battery",
                                     "Battery low",
                                     root.level + "% remaining — plug in."]);
        } else if (root.warned && (root.charging || root.level >= root.clearAt)) {
            root.warned = false;
        }
    }

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
