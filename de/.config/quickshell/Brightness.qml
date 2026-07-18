import Quickshell
import Quickshell.Io
import QtQuick

// eww `brightness` window. Bottom-left, y=900, 420x75.
// Software gamma via brightness.sh (wl-gammarelay-rs, all outputs). Range 10..100.
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(900) }
    implicitWidth: s(420)
    implicitHeight: s(75)

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/brightness.sh"
    property int level: 100

    Process {
        id: getProc
        command: [root.script, "get"]
        stdout: StdioCollector { onStreamFinished: if (!drag.pressed) root.level = Number(text.trim()) || root.level }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: getProc.running = true }

    function apply(px, w) {
        root.level = Math.round(Math.max(10, Math.min(100, 10 + (px / w) * 90)));
        Quickshell.execDetached([root.script, "set", "" + root.level]);
    }

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

        // Flat slider: surface0 track, yellow fill, text-coloured handle.
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
                }
            }
            Rectangle {
                width: root.s(16); height: root.s(16); radius: 0
                color: Theme.text
                y: (parent.height - height) / 2
                x: Math.max(0, Math.min(track.width - width, track.width * (root.level - 10) / 90 - width / 2))
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                onPressed: (m) => root.apply(m.x, width)
                onPositionChanged: (m) => { if (pressed) root.apply(m.x, width); }
            }
        }
    }
}
