import Quickshell
import QtQuick

// Minimal drun-style app launcher (replaces `rofi -show drun`).
// Triggered by IPC so the reach keybind is just `qs ipc call launcher toggle`.
// Picker owns the overlay, the IPC target and the focused-monitor logic; this
// file is just the query, the list, and the keys.
//
// Geometry/colours match spotlight-dark.rasi: 35%x50%, 1px mauve border, zero
// padding, input font 20, tight rows, dark (#11111b) selection with #bac2de text.
Picker {
    id: root

    ipcTarget: "launcher"
    widthFraction: 0.35
    heightFraction: 0.5

    property string query: ""
    property int selected: 0

    // A live binding, NOT a snapshot. DesktopEntries scans asynchronously —
    // `applications.values` is empty at load and fills ~50ms later — so a list
    // computed once when the box opened stayed empty for that entire open if
    // you hit Super+Space right after the shell started or hot-reloaded. Read
    // inside a binding, a late scan (or a rescan when a package is installed)
    // fills the list that's already on screen.
    readonly property var results: {
        var q = root.query.toLowerCase();
        var vals = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < vals.length; i++) {
            var a = vals[i];
            if (a.noDisplay) continue;
            if (q === "" || a.name.toLowerCase().indexOf(q) !== -1) out.push(a);
        }
        out.sort(function (x, y) { return x.name.localeCompare(y.name); });
        return out;
    }
    onQueryChanged: root.selected = 0

    // Hover must not fight the keyboard. Qt delivers a hover move whenever the
    // row *under* the cursor changes — including when arrowing down scrolls the
    // list past a motionless pointer — so neither `entered` nor `positionChanged`
    // is evidence that the user pointed at anything. Compare window-space
    // coordinates and only take the selection when they actually moved. The
    // first event after opening merely records the baseline, so a launcher
    // mapped under the cursor doesn't preselect the row it happened to land on
    // (Super+Space Return would have launched it).
    property point lastPointer: Qt.point(-1, -1)
    property bool pointerSeen: false

    function hoverSelect(p, i) {
        if (!root.pointerSeen) { root.pointerSeen = true; root.lastPointer = p; return; }
        if (Math.abs(p.x - root.lastPointer.x) < 1 && Math.abs(p.y - root.lastPointer.y) < 1) return;
        root.lastPointer = p;
        root.selected = i;
    }
    function launch() {
        if (root.selected < 0 || root.selected >= root.results.length) return;
        root.results[root.selected].execute();
        root.hide();
    }

    box: Component {
        Column {
            id: content
            spacing: 0

            // Called by Picker every time the box appears on an output.
            function reset() {
                field.text = ""; root.query = ""; root.selected = 0;
                root.pointerSeen = false;
                field.forceActiveFocus();
            }

            // Input row (rofi inputbar: no box, just the entry).
            Item {
                width: parent.width
                height: 52

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: 24
                    focus: true
                    onTextChanged: root.query = text
                    Keys.onPressed: function (e) {
                        if (e.key === Qt.Key_Escape) { root.hide(); e.accepted = true; }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launch(); e.accepted = true; }
                        else if (e.key === Qt.Key_Down || (e.key === Qt.Key_J && (e.modifiers & Qt.ControlModifier))) {
                            root.selected = Math.min(root.selected + 1, root.results.length - 1); e.accepted = true;
                        } else if (e.key === Qt.Key_Up || (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier))) {
                            root.selected = Math.max(root.selected - 1, 0); e.accepted = true;
                        }
                    }
                }

                Txt {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    text: "Search…"; color: Theme.subtext0
                    font.pixelSize: 24
                    visible: field.text === ""
                }
            }

            // Results.
            Item {
                width: parent.width
                height: parent.height - 52

                Txt {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: root.query === "" ? "no applications found" : "no matches"
                    color: Theme.subtext0
                    font.pixelSize: 17
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    model: root.results
                    currentIndex: root.selected
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: list.width; height: 38
                        color: index === root.selected ? "#11111b" : "transparent"

                        // positionChanged, NOT entered: arrowing down scrolls
                        // the view, which slides a different row under a
                        // motionless cursor and fires entered — so every
                        // keypress handed the selection straight back to
                        // whatever the pointer happened to sit on. Only real
                        // pointer movement should steal it.
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onPositionChanged: function (e) { root.hoverSelect(mapToItem(null, e.x, e.y), index); }
                            onClicked: { root.selected = index; root.launch(); }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26; height: 26
                                sourceSize.width: 26; sourceSize.height: 26
                                fillMode: Image.PreserveAspectFit
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, "application-x-executable") : ""
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: index === root.selected ? "#bac2de" : Theme.text
                                font.pixelSize: 19
                            }
                        }
                    }
                }
            }
        }
    }
}
