import QtQuick

// eww `clock` window. Top-left, y=14 clears reach's status bar.
// Time/date computed natively (was `date` polled at 1s/60s).
Widget {
    id: root
    pad: 15
    anchors { top: true; left: true }
    margins { top: s(14) }
    implicitWidth: s(420)
    implicitHeight: s(150)

    property string timeStr: ""
    property string dateStr: ""

    readonly property var months: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]

    function pad2(n) { return ("" + n).padStart(2, "0"); }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            // eww used +%H:%M:%S %p -> 24h clock with an AM/PM suffix.
            root.timeStr = root.pad2(d.getHours()) + ":" + root.pad2(d.getMinutes())
                         + ":" + root.pad2(d.getSeconds()) + " " + (d.getHours() < 12 ? "AM" : "PM");
            root.dateStr = root.months[d.getMonth()] + " " + root.pad2(d.getDate()) + ", " + d.getFullYear();
        }
    }

    Column {
        anchors.fill: parent
        Txt { text: root.timeStr; font.bold: true; font.pixelSize: root.s(58) }
        Txt { text: root.dateStr; color: Theme.subtext0; font.pixelSize: root.s(32) }
    }
}
