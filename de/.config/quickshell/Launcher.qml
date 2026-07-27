import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Minimal drun-style app launcher (replaces `rofi -show drun`).
// Triggered by IPC so the reach keybind is just `qs ipc call launcher toggle`.
//   - one overlay per output; the box is drawn only on the monitor under the
//     pointer. reach uses sloppy focus, so the pointer's monitor IS the focused
//     one — reach has no IPC to ask, and it grants keyboard focus to every
//     layer surface, so pointer containment is what actually singles one out.
//   - type to fuzzy-filter DesktopEntries by name, Up/Down (or Ctrl+K/J) to move,
//     Enter launches via the entry's own exec, Esc / click-outside closes.
Scope {
    id: root
    property bool open: false

    // Shared state — a single logical launcher spread across per-output surfaces.
    property var results: []
    property int selected: 0

    // Name of the output the launcher is shown on. Blanked on open, then latched
    // to whichever output the pointer enters — so the box never flashes on the
    // previously-focused monitor before the pointer's location is known.
    property string activeScreen: ""

    // If no pointer-enter ever arrives (cursor dead-still as the surfaces map),
    // fall back to DP-2 so the box still shows somewhere.
    onOpenChanged: if (open) { activeScreen = ""; fallback.restart(); }
    Timer {
        id: fallback
        interval: 150
        onTriggered: if (root.open && root.activeScreen === "") root.activeScreen = "DP-2";
    }

    function show()   { root.open = true; }
    function hide()   { root.open = false; }
    function toggle() { root.open = !root.open; }

    // Recompute the filtered/sorted app list from a query string.
    function refresh(q) {
        q = (q || "").toLowerCase();
        var vals = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < vals.length; i++) {
            var a = vals[i];
            if (a.noDisplay) continue;
            if (q === "" || a.name.toLowerCase().indexOf(q) !== -1) out.push(a);
        }
        out.sort(function (x, y) { return x.name.localeCompare(y.name); });
        root.results = out;
        root.selected = 0;
    }
    function launch() {
        if (root.selected < 0 || root.selected >= root.results.length) return;
        root.results[root.selected].execute();
        root.hide();
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(); }
        function show(): void   { root.show(); }
        function hide(): void   { root.hide(); }
    }

    // One surface per output. Every surface is a full-screen overlay, but only
    // the one whose area holds the pointer (the focused monitor) draws the box.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.open

            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            // Click-outside closes; hover latches this as the focused output.
            // Only latch (never clear) so mousing onto the box doesn't hide it.
            MouseArea {
                id: outside
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.hide()
                onContainsMouseChanged: if (containsMouse && root.open) root.activeScreen = win.modelData.name
            }

            // Matches spotlight-dark.rasi: 35%x50%, 1px mauve border, zero padding,
            // input font 20, tight rows, dark (#11111b) selection with #bac2de text.
            // Shown only on the output the pointer picked (the focused monitor).
            Rectangle {
                id: box
                visible: root.open && win.modelData.name === root.activeScreen
                onVisibleChanged: if (visible) { field.text = ""; root.refresh(""); field.forceActiveFocus(); }
                width: Math.round(win.width * 0.35)
                height: Math.round(win.height * 0.5)
                anchors.centerIn: parent
                color: Theme.base
                border.color: Theme.mauve
                border.width: 1
                radius: Theme.borderRadius

                MouseArea { anchors.fill: parent }   // swallow clicks so they don't close

                Column {
                    anchors.fill: parent
                    anchors.margins: box.border.width
                    spacing: 0

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
                            onTextChanged: root.refresh(text)
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
                    ListView {
                        id: list
                        width: parent.width
                        height: parent.height - 52
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

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selected = index
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
}
