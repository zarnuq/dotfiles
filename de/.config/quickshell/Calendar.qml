import Quickshell
import QtQuick

// Left bar, 420 wide: stretches from under the brightness widget (150+75) down
// to the top of the weather card, so it absorbs whatever height is left over:
// anchoring top+bottom stretches it over the bar's leftover space.
// ICS calendar via calendar.sh (Python icalendar), polled 60s.
Widget {
    id: root
    anchors { top: true; bottom: true; left: true }
    margins { top: s(225); bottom: s(600) }
    implicitWidth: s(420)

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/calendar.sh"
    property var events: []      // [{ day, time, summary, location, color }]

    Poll {
        id: poll
        command: [root.script, "events"]
        // calendar.sh caches for 300s, so a shorter interval can only pay for
        // python + icalendar + a reparse of the ICS to print the same bytes.
        // The header's refresh button calls refresh() for the impatient case.
        interval: 300000
        onJsonData: v => root.events = v || []
    }

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
                    onClicked: { Quickshell.execDetached([root.script, "refresh"]); poll.refresh(); }
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
