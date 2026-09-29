pragma ComponentBehavior: Bound
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Top-left, flush under the bar.
// Time/date computed natively (was `date` polled at 1s/60s).
Widget {
    id: root
    pad: 15
    anchors { top: true; left: true }
    implicitWidth: s(420)
    implicitHeight: s(150)

    property string timeStr: ""
    property string dateStr: ""

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            // eww used +%H:%M:%S %p -> 24h clock with an AM/PM suffix. `HH`
            // stays 24-hour even with `AP` in the format (`hh` would not).
            root.timeStr = Qt.formatDateTime(d, "HH:mm:ss AP");
            root.dateStr = Qt.formatDateTime(d, "MMMM dd, yyyy");
        }
    }

    Column {
        anchors.fill: parent
        Txt { text: root.timeStr; font.bold: true; font.pixelSize: root.s(58) }
        Txt { text: root.dateStr; color: Theme.subtext0; font.pixelSize: root.s(32) }
    }
}
