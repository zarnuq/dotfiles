pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Obsidian habit tracker, top-right: today and yesterday, in Obsidian's order.
//
// Reads and writes the habit-tracker plugin's own data.json in the ~/notes vault
// (the Habits.hbt note is an empty placeholder; the plugin keeps everything in
// data.json, keyed "YYYY-MM-DD" in local time). Clicking a box rewrites that
// file. Obsidian holds the data in memory and rewrites the whole file on its own
// next tick, so the plugin's onExternalSettingsChange (added to its main.js in
// the vault) reloads it — without that, a click here is lost on the next click
// in Obsidian.
Widget {
    id: root
    anchors { top: true; right: true }
    implicitWidth: s(300)
    implicitHeight: body.height + s(root.pad * 2)

    property var groups: []          // settings.habitGroups: [{ name, habits: [] }]
    property var days: ({})          // data: { "YYYY-MM-DD": { habit: bool } }
    property date now: new Date()

    // Recomputed each minute so the two columns roll over at midnight.
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.now = new Date() }

    readonly property var dates: {
        var y = new Date(root.now);
        y.setDate(y.getDate() - 1);
        return [root.now, y];
    }
    function key(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    function done(d, habit) { var v = root.days[root.key(d)]; return !!(v && v[habit]); }

    readonly property int total: root.groups.reduce(function(n, g) { return n + g.habits.length; }, 0)
    readonly property int todayDone: root.groups.reduce(function(n, g) {
        return n + g.habits.filter(function(h) { return root.done(root.now, h); }).length;
    }, 0)

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/notes/.obsidian/plugins/habit-tracker/data.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                var v = JSON.parse(text());
                root.groups = (v.settings && v.settings.habitGroups) || [];
                root.days = v.data || {};
            } catch (e) {}
        }
    }

    // Re-read the file as it is now rather than writing root.days back, so a
    // tick Obsidian saved a moment ago isn't overwritten. Same JSON layout
    // Obsidian's saveData writes (two-space indent).
    function toggle(d, habit): void {
        var v;
        try { v = JSON.parse(store.text()); } catch (e) { return; }
        var k = root.key(d);
        v.data = v.data || {};
        v.data[k] = v.data[k] || {};
        v.data[k][habit] = !v.data[k][habit];
        root.days = v.data;
        store.setText(JSON.stringify(v, null, 2));
    }

    readonly property real col: s(40)

    Column {
        id: body
        width: parent.width
        spacing: root.s(4)

        CardHeader {
            icon: "󰄲"
            iconColor: root.total && root.todayDone === root.total ? Theme.green : Theme.mauve
            label: "Habits"
            Txt { font.pixelSize: root.s(14); text: root.total ? root.todayDone + "/" + root.total : "no data" }
        }

        // Day labels over the two checkbox columns.
        Row {
            anchors.right: parent.right
            Repeater {
                model: root.dates
                delegate: Txt {
                    id: day
                    required property var modelData
                    required property int index
                    width: root.col
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: root.s(12)
                    color: day.index === 0 ? Theme.text : Theme.overlay0
                    text: Qt.formatDate(day.modelData, "ddd")
                }
            }
        }

        Repeater {
            model: root.groups
            delegate: Column {
                id: group
                required property var modelData
                width: body.width
                spacing: root.s(4)

                Txt {
                    text: group.modelData.name.toUpperCase()
                    color: Theme.overlay0
                    font.pixelSize: root.s(11)
                    font.bold: true
                }

                Repeater {
                    model: group.modelData.habits
                    delegate: Row {
                        id: habit
                        required property string modelData
                        width: group.width

                        Txt {
                            width: parent.width - root.col * 2
                            elide: Text.ElideRight
                            font.pixelSize: root.s(13)
                            text: habit.modelData
                        }
                        Repeater {
                            model: root.dates
                            delegate: Item {
                                id: cell
                                required property var modelData
                                readonly property bool on: root.done(cell.modelData, habit.modelData)
                                width: root.col
                                height: root.s(16)
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggle(cell.modelData, habit.modelData)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: root.s(12); height: width
                                    radius: Theme.borderRadius
                                    color: cell.on ? Theme.mauve : "transparent"
                                    border.color: cell.on ? Theme.mauve : Theme.surface1
                                    border.width: root.s(1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
