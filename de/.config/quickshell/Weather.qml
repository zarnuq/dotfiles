import Quickshell
import Quickshell.Io
import QtQuick

// eww `weather` window. Bottom-left, y=600, 140 wide.
// One wttr.in request (10 min) split into temp / condition / humidity / wind.
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(600) }
    implicitWidth: s(140)
    implicitHeight: s(150)

    property string temp: "N/A"
    property string condition: ""
    property string humidity: ""
    property string wind: ""

    Process {
        id: proc
        command: ["sh", "-c", "curl -s 'wttr.in/?format=%c%t|%C|%h|%w' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.replace(/\x1b\[[0-9;]*m/g, "").trim().split("|");  // strip ANSI colour codes
                if (p.length < 4) return;
                root.temp = p[0]; root.condition = p[1]; root.humidity = p[2]; root.wind = p[3];
            }
        }
    }
    Timer { interval: 600000; running: true; repeat: true; triggeredOnStart: true; onTriggered: proc.running = true }

    Column {
        anchors.fill: parent
        Txt { text: root.temp;      font.pixelSize: root.s(24) }
        Txt { text: root.condition; color: Theme.subtext0; font.pixelSize: root.s(20) }
        Txt { text: "💧" + root.humidity; color: Theme.subtext0; font.pixelSize: root.s(20) }
        Txt { text: "  💨" + root.wind;   color: Theme.subtext0; font.pixelSize: root.s(20) }
    }
}
