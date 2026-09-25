pragma ComponentBehavior: Bound
import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Sys, Volume,
// Reach, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

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

        CardHeader {
            icon: "󰃟"; iconColor: Theme.yellow; label: "brightness"
            Txt { text: root.level + "%"; font.pixelSize: root.s(14) }
        }

        // Flat gauge: surface0 track, yellow fill, centred in a taller strip.
        Item {
            width: parent.width
            height: root.s(16)

            Gauge {
                anchors.verticalCenter: parent.verticalCenter
                fraction: (root.level - 10) / 90
                fillColor: Theme.yellow
                animated: true
            }
        }
    }
}
