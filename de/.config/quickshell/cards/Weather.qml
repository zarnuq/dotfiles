pragma ComponentBehavior: Bound
import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Sys, Volume,
// Reach, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

// One wttr.in request (10 min) split into temp / condition / humidity / wind.
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(450) }
    implicitWidth: s(420)
    implicitHeight: s(150)

    property string temp: "N/A"
    property string condition: ""
    property string humidity: ""
    property string wind: ""

    Poll {
        command: ["sh", "-c", "curl -s 'wttr.in/?format=%c%t|%C|%h|%w' 2>/dev/null"]
        interval: 600000
        onData: function (text) {
            var p = text.replace(/\x1b\[[0-9;]*m/g, "").trim().split("|");  // strip ANSI colour codes
            if (p.length < 4) return;
            root.temp = p[0]; root.condition = p[1]; root.humidity = p[2]; root.wind = p[3];
        }
    }

    // Temperature carries the card; the three details stack beside it rather
    // than under it, so a full-width card isn't mostly blank.
    Row {
        anchors.fill: parent
        spacing: root.s(18)

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temp
            font.pixelSize: root.s(44)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.s(4)
            Txt { text: root.condition; font.pixelSize: root.s(20) }
            Txt { text: "💧 " + root.humidity; color: Theme.subtext0; font.pixelSize: root.s(18) }
            Txt { text: "💨 " + root.wind;   color: Theme.subtext0; font.pixelSize: root.s(18) }
        }
    }
}
