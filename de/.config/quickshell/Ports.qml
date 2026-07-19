import Quickshell
import Quickshell.Io
import QtQuick

// eww `ports` window. Bottom-left, y=300, 210 wide.
// Listening ports from ports.sh (ss+jq), polled 5s.
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(300) }
    implicitWidth: s(210)
    implicitHeight: s(150)

    property var ports: []   // [{ proto, port, process }]

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/ports.sh"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.ports = JSON.parse(text) || []; } catch (e) { root.ports = []; } }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: proc.running = true }

    Column {
        anchors.fill: parent
        spacing: root.s(8)

        // Header: icon, title, count badge.
        Row {
            id: header
            width: parent.width
            spacing: root.s(8)
            Txt { text: "󰖟"; color: Theme.red; font.pixelSize: root.s(16) }
            Txt {
                text: "ports"; color: Theme.subtext0; font.pixelSize: root.s(14)
                width: parent.width - x - count.width - parent.spacing
                elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
            }
            Rectangle {
                id: count
                color: Theme.surface0; radius: root.s(10)
                implicitWidth: countTxt.width + root.s(16); implicitHeight: countTxt.height + root.s(4)
                Txt { id: countTxt; anchors.centerIn: parent; text: root.ports.length; font.pixelSize: root.s(12) }
            }
        }

        ListView {
            width: parent.width
            height: parent.height - header.height - parent.spacing
            clip: true
            spacing: root.s(4)
            model: root.ports

            Txt {
                visible: root.ports.length === 0
                text: "No listening ports"; color: Theme.subtext0; font.pixelSize: root.s(12)
            }

            delegate: Rectangle {
                width: ListView.view.width
                color: Theme.surface0; radius: root.s(6)
                implicitHeight: row.height + root.s(12)
                Row {
                    id: row
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: root.s(10); rightMargin: root.s(10) }
                    spacing: root.s(8)
                    Rectangle {
                        color: Theme.surface1; radius: root.s(4); anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: proto.width + root.s(12); implicitHeight: proto.height + root.s(4)
                        Txt { id: proto; anchors.centerIn: parent; text: modelData.proto; color: Theme.subtext0; font.pixelSize: root.s(10) }
                    }
                    Txt {
                        text: modelData.port; color: Theme.red; font.bold: true; font.pixelSize: root.s(14)
                        width: root.s(50); anchors.verticalCenter: parent.verticalCenter
                    }
                    Txt {
                        text: modelData.process; color: Theme.subtext0; font.pixelSize: root.s(12)
                        width: parent.width - x; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
