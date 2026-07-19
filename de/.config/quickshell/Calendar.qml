import Quickshell
import Quickshell.Io
import QtQuick

// eww `outlook` window. Bottom-left, y=750, 420 wide.
// ICS calendar via calendar.sh (Python icalendar), polled 60s.
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(750) }
    implicitWidth: s(420)
    implicitHeight: s(150)

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/calendar.sh"
    property var events: []      // [{ day, time, summary, location, color }]

    Process {
        id: proc
        command: [root.script, "events"]
        stdout: StdioCollector { onStreamFinished: { try { root.events = JSON.parse(text) || []; } catch (e) { root.events = []; } } }
    }
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: proc.running = true }

    Column {
        anchors.fill: parent
        spacing: root.s(8)

        // Header: icon, title, refresh (bordered bottom, like eww's cal-header).
        Item {
            id: header
            width: parent.width
            implicitHeight: headerRow.height + root.s(8)
            Row {
                id: headerRow
                width: parent.width
                spacing: root.s(8)
                Txt { text: "󰃭"; color: Theme.blue; font.pixelSize: root.s(16) }
                Txt {
                    text: "calendar"; color: Theme.subtext0; font.pixelSize: root.s(14)
                    width: parent.width - x - refresh.width - parent.spacing; verticalAlignment: Text.AlignVCenter
                }
                HeaderBtn {
                    id: refresh
                    icon: "󰑓"; size: root.s(14)
                    onClicked: { Quickshell.execDetached([root.script, "refresh"]); proc.running = true; }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: root.s(1); color: Theme.surface0 }
        }

        ListView {
            width: parent.width
            height: parent.height - header.height - parent.spacing
            clip: true
            spacing: root.s(6)
            model: root.events

            Txt {
                visible: root.events.length === 0
                text: "No upcoming events"; color: Theme.subtext0; font.pixelSize: root.s(12)
            }

            delegate: Rectangle {
                id: ev
                required property var modelData
                width: ListView.view.width
                color: Theme.surface0; radius: root.s(8)
                implicitHeight: body.height + root.s(16)

                Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: root.s(3); color: ev.modelData.color }   // border-left accent

                Column {
                    id: body
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: root.s(10); rightMargin: root.s(10) }
                    spacing: root.s(2)
                    Row {
                        width: parent.width
                        Txt { text: ev.modelData.day; color: ev.modelData.color; font.bold: true; font.pixelSize: root.s(11) }
                        Txt { text: ev.modelData.time; color: Theme.subtext0; font.pixelSize: root.s(11)
                              width: parent.width - x; horizontalAlignment: Text.AlignRight }
                    }
                    Txt { text: ev.modelData.summary; font.pixelSize: root.s(13); width: parent.width; wrapMode: Text.WordWrap }
                    Txt {
                        visible: ev.modelData.location !== ""
                        text: "󰍎 " + ev.modelData.location; color: Theme.subtext0; font.pixelSize: root.s(11)
                        width: parent.width; elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
