pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Left bar, 420 wide: anchored top+bottom from under the brightness widget
// (150+75) down to the top of the now-playing card, so it absorbs whatever
// height is left over.
// ICS calendar via calendar.sh (stdlib Python), polled every 5 min.
Widget {
    id: root
    anchors { top: true; bottom: true; left: true }
    margins { top: s(225); bottom: s(330) }
    implicitWidth: s(420)

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/calendar.sh"
    property var events: []      // [{ day, time, summary, location, days_from_today }]

    // Rainbow by distance from today: red today, peach tomorrow, … mauve from
    // six days on (and for everything further out). A multi-day event already
    // under way has a negative offset and counts back from the end (-1 mauve,
    // -7 red), which is what the script's old colour table did by Python's
    // negative indexing.
    readonly property var dayColors: [Theme.red, Theme.peach, Theme.yellow, Theme.green,
                                        Theme.blue, Theme.lavender, Theme.mauve]
    function dayColor(d) { return root.dayColors[d < 0 ? d + 7 : Math.min(d, 6)]; }

    Poll {
        command: [root.script, "events"]
        // calendar.sh caches for 300s, so a shorter interval can only pay for
        // python + a reparse of the ICS to print the same bytes.
        interval: 300000
        onJsonData: v => root.events = v || []
    }

    // The header's refresh button, for the impatient case: `refresh` drops the
    // cache, refetches and prints the same JSON `events` does. One run — it
    // used to fire this detached alongside an `events` poll, which raced it
    // and usually re-read the stale cache before the fetch had replaced it.
    Poll {
        id: refresher
        running: false
        command: [root.script, "refresh"]
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
            CardHeader {
                id: headerRow
                spacing: root.s(8)
                icon: "󰃭"; iconColor: Theme.blue; iconSize: root.s(16); label: "calendar"
                HeaderBtn { icon: "󰑓"; onClicked: refresher.refresh() }
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

            delegate: ListCard {
                id: ev
                required property var modelData
                readonly property color tint: root.dayColor(ev.modelData.days_from_today)
                width: ListView.view.width
                hMargin: root.s(10)
                spacing: root.s(2)
                accent: ev.tint     // border-left accent

                Row {
                    width: parent.width
                    Txt { text: ev.modelData.day; color: ev.tint; font.bold: true; font.pixelSize: root.s(11) }
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
