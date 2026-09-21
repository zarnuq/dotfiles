import Quickshell
import QtQuick

// Top of the left bar's lower stack: sits directly under the clock (150 tall),
// so the calendar below it can stretch into whatever is left. 420x75.
//
// A READOUT, not a control. reach owns gamma now (its gamma.zig holds the
// wlr-gamma-control objects for the whole session) and publishes the level on
// its state socket, so the value arrives through the Reach singleton — no
// `brightness.sh get` poll every 2s, and no subprocess at all. Setting it is
// Super+Alt+Left/Right, which runs inside reach with no round trip; the socket
// is deliberately write-only, so there is nothing for a drag here to call.
Widget {
    id: root
    anchors { top: true; left: true }
    margins { top: s(150) }
    implicitWidth: s(420)
    implicitHeight: s(75)

    // 10 is reach's floor (a keybind must never be able to black the screen out),
    // so the bar measures the 10..100 range rather than 0..100.
    readonly property int level: Reach.brightness

    Column {
        anchors.fill: parent
        spacing: root.s(8)

        Row {
            width: parent.width
            spacing: root.s(10)
            Txt { text: "󰃟"; color: Theme.yellow; font.pixelSize: root.s(18) }
            Txt {
                text: "brightness"; color: Theme.subtext0; font.pixelSize: root.s(14)
                width: parent.width - x - value.width - parent.spacing; verticalAlignment: Text.AlignVCenter
            }
            Txt { id: value; text: root.level + "%"; font.pixelSize: root.s(14) }
        }

        // Flat gauge: surface0 track, yellow fill.
        Item {
            width: parent.width
            height: root.s(16)

            Rectangle {
                id: track
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: root.s(8)
                color: Theme.surface0
                Rectangle {
                    height: parent.height
                    width: parent.width * (root.level - 10) / 90
                    color: Theme.yellow
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }
        }
    }
}
