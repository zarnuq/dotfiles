import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Base for the full-screen pickers (Launcher, WallpaperPicker).
//
// Everything here is the scaffolding both of them need and neither of them is
// really about: IPC toggle, one overlay per output, and the trick that decides
// WHICH output to draw on.
//
// That trick: reach exposes no IPC to ask which monitor is focused, and it hands
// keyboard focus to every layer surface, so a surface is mapped on every output
// and only the one containing the pointer draws the box. Under reach's sloppy
// focus the pointer's monitor IS the focused one. `activeScreen` is blanked on
// open so the box never flashes on the previously-focused monitor, then latched
// by the first pointer-enter; if the cursor is dead still as the surfaces map,
// the fallback timer picks the main screen.
//
// A picker supplies `box` (its content, instantiated per output) and its own
// state/keys. If the content defines `reset()`, it's called each time the box
// becomes visible — where a picker clears its query and takes focus.
Scope {
    id: root

    property string ipcTarget: ""
    property Component box: null
    property real widthFraction: 0.35    // box size as a fraction of the output
    property real heightFraction: 0.5
    property int boxWidth: 0             // px; overrides widthFraction when > 0
    property int boxHeight: 0

    // Draw the box on every output instead of just the pointer's. Keyboard
    // focus still goes to exactly one surface — reach hands it to every layer
    // surface it can, and if several accepted keys each one would drive the
    // shared selection, so a single j would jump three rows.
    property bool allScreens: false

    property bool open: false
    property string activeScreen: ""

    // ── the selection ────────────────────────────────────────────────────
    // Every picker has one, and the two menu-shaped ones (Settings, Audio)
    // additionally lay their content out as a flat `rows` list in which some
    // entries are non-selectable group headers. Both carried verbatim copies of
    // all three helpers below; a picker that doesn't use `rows` just leaves it
    // empty and drives `selected` itself, as Launcher and WallpaperPicker do.
    property var rows: []
    property int selected: 0

    function selectable(i) { return i >= 0 && i < root.rows.length && root.rows[i].kind !== "header"; }

    function firstSelectable() {
        for (var i = 0; i < root.rows.length; i++)
            if (root.rows[i].kind !== "header") return i;
        return 0;
    }

    // Headers aren't stops on the way down the list; step over them.
    function move(delta) {
        var i = root.selected + delta;
        while (i >= 0 && i < root.rows.length && root.rows[i].kind === "header") i += delta;
        if (root.selectable(i)) root.selected = i;
    }

    signal opened()

    function show()   { root.open = true; }
    function hide()   { root.open = false; }
    function toggle() { root.open = !root.open; }

    onOpenChanged: if (open) { activeScreen = ""; pointerSeen = false; fallback.restart(); root.opened(); }

    // Hover must not fight the keyboard. Qt delivers a hover move whenever the
    // row *under* the cursor changes — including when arrowing through a list
    // scrolls it past a motionless pointer — so neither `entered` nor
    // `positionChanged` is evidence that the user pointed at anything. A picker
    // asks this before letting hover take the selection: true only when the
    // pointer physically moved in window space since the last hover event.
    //
    // The first event after opening only records the baseline (pointerSeen is
    // cleared on open), so an overlay mapped under the cursor never preselects
    // the row it happened to land on — Return would otherwise launch or switch
    // to something nobody pointed at.
    property point lastPointer: Qt.point(-1, -1)
    property bool pointerSeen: false

    function hoverMoved(item, e) {
        var p = item.mapToItem(null, e.x, e.y);
        var moved = root.pointerSeen
                    && (Math.abs(p.x - root.lastPointer.x) >= 1 || Math.abs(p.y - root.lastPointer.y) >= 1);
        root.pointerSeen = true;
        root.lastPointer = p;
        return moved;
    }

    Timer {
        id: fallback
        interval: 150
        onTriggered: if (root.open && root.activeScreen === "") root.activeScreen = root.defaultScreen();
    }

    // The main screen when it's there, else whatever the first output is — on the
    // laptop there is no DP-2, and latching a name that matches no output would
    // leave the picker mapped but invisible on every monitor.
    function defaultScreen() {
        var m = Config.screen(Config.mainScreen);
        if (m) return m.name;
        var all = Quickshell.screens;
        return all.length > 0 ? all[0].name : "";
    }

    IpcHandler {
        target: root.ipcTarget
        function toggle(): void { root.toggle(); }
        function show(): void   { root.show(); }
        function hide(): void   { root.hide(); }
    }

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
            // Only the window drawing the box grabs the keyboard, so keystrokes
            // land on the visible box's monitor — not whatever output reach would
            // otherwise pick when every surface requests Exclusive.
            WlrLayershell.keyboardFocus: (root.open && win.modelData.name === root.activeScreen)
                                         ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            // Click-outside closes; hover latches this as the focused output.
            // Only latch (never clear) so mousing onto the box doesn't hide it.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.hide()
                onContainsMouseChanged: if (containsMouse && root.open) root.activeScreen = win.modelData.name
            }

            Rectangle {
                id: boxFrame
                visible: root.open && (root.allScreens || win.modelData.name === root.activeScreen)
                onVisibleChanged: if (visible && loader.item && loader.item.reset) loader.item.reset();
                width: root.boxWidth > 0 ? root.boxWidth : Math.round(win.width * root.widthFraction)
                height: root.boxHeight > 0 ? root.boxHeight : Math.round(win.height * root.heightFraction)
                anchors.centerIn: parent
                color: Theme.base
                border.color: Theme.mauve
                border.width: 1
                radius: Theme.borderRadius

                MouseArea { anchors.fill: parent }   // swallow clicks so they don't close

                Loader {
                    id: loader
                    anchors.fill: parent
                    anchors.margins: boxFrame.border.width
                    sourceComponent: root.box
                }
            }
        }
    }
}
