import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Base for the full-screen pickers and menus.
//
// Owns IPC toggle, one overlay per output, the box's size, list navigation and
// its keys, and the logic that decides which output draws the content.
//
// That trick: reach exposes no IPC to ask which monitor is focused, and it hands
// keyboard focus to every layer surface, so a surface is mapped on every output
// and only the one containing the pointer draws the box. Under reach's sloppy
// focus the pointer's monitor IS the focused one. `activeScreen` is blanked on
// open so the box never flashes on the previously-focused monitor, then latched
// by the first pointer-enter; if the cursor is dead still as the surfaces map,
// the fallback timer picks the main screen.
//
// A picker supplies `box` (its content, built when the box appears) and its own
// rows, actions and extra keys. Focus and the initial selection are handled
// here; a `reset()` on the content is called after them, for the picker's own
// state (a query to clear, a password field to drop).
Scope {
    id: root

    function s(n) { return Config.s(n); }

    property string ipcTarget: ""
    property Component box: null
    property real widthFraction: 0.35    // box size as a fraction of the output
    property real heightFraction: 0.5
    property int boxWidth: 0             // px; overrides widthFraction when > 0

    // A list picker is as tall as its rows — the same sum was written out in
    // four files. A picker that drives its own list leaves `rows` empty and
    // falls back to heightFraction, which is what 0 means here.
    property int headerHeight: s(28)
    property int rowHeight: s(34)
    property int barHeight: 0            // bottom status bar, when the picker draws one
    property int minBoxHeight: 0
    property int boxHeight: {
        if (rows.length === 0) return 0;
        var h = s(12) * 2 + barHeight;
        for (var i = 0; i < rows.length; i++)
            h += rows[i].kind === "header" ? headerHeight : rowHeight;
        return Math.max(h, minBoxHeight);
    }

    // Draw the box on every output instead of just the pointer's. Keyboard
    // focus still goes to exactly one surface — reach hands it to every layer
    // surface it can, and if several accepted keys each one would drive the
    // shared selection, so a single j would jump three rows.
    property bool allScreens: false

    property bool open: false
    property string activeScreen: ""

    // ── the selection ────────────────────────────────────────────────────
    // The list pickers (Settings, Audio, the two Network instances) use a flat
    // `rows` list containing optional non-selectable group headers. Launcher
    // and WallpaperPicker leave it empty and drive `selected` against their own
    // results instead.
    property var rows: []
    property int selected: 0

    function selectable(i) { return i >= 0 && i < root.rows.length && root.rows[i].kind !== "header"; }

    function firstSelectable() {
        for (var i = 0; i < root.rows.length; i++)
            if (root.rows[i].kind !== "header") return i;
        return 0;
    }

    // A list that shrinks under the selection — an AP fading out of a scan, an
    // app stream ending — would otherwise leave `selected` past the end, where
    // Return does nothing. Picker owns both, so it owns the invariant; the two
    // menus that remembered to do this for themselves had the same six lines.
    onRowsChanged: if (!selectable(selected)) selected = firstSelectable();

    // Headers aren't stops on the way down the list; step over them.
    function move(delta) {
        var i = root.selected + delta;
        while (i >= 0 && i < root.rows.length && root.rows[i].kind === "header") i += delta;
        if (root.selectable(i)) root.selected = i;
    }

    // Escape, Return and j/k/arrows are the picker's contract, not any one
    // menu's — four files opened with the identical `plain` dance and the
    // identical triple condition. A picker calls this first and handles only
    // its own extra keys. `activate(i)` is the subclass's; a picker without
    // one (Launcher, WallpaperPicker drive their own lists) just won't see
    // Return here.
    function navKey(e) {
        // j/k bare, or Ctrl+j/k for a picker whose box has a text field.
        var vim = !(e.modifiers & Qt.AltModifier) || (e.modifiers & Qt.ControlModifier);
        if (e.key === Qt.Key_Escape) root.hide();
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (root.activate) root.activate(root.selected);
        } else if (e.key === Qt.Key_Down || (e.key === Qt.Key_J && vim)) root.move(1);
        else if (e.key === Qt.Key_Up || (e.key === Qt.Key_K && vim)) root.move(-1);
        else return false;
        e.accepted = true;
        return true;
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

    // Latching a name that matches no output would leave the picker mapped but
    // invisible on every monitor, so this is Config's pin — the main screen
    // when it's there, else the first one (on the laptop there is no DP-2).
    function defaultScreen() { return Config.pinScreen ? Config.pinScreen.name : ""; }

    // No `show` here on purpose: `qs ipc call <target> show` collides with the
    // `qs ipc show` subcommand — the CLI prints the target listing, exits 0 and
    // never reaches the handler, so the function only looked like API. `hide`
    // and `toggle` both arrive normally.
    IpcHandler {
        target: root.ipcTarget
        function toggle(): void { root.toggle(); }
        function hide(): void   { root.hide(); }
        // `open`, not `show` — same function, a name the CLI does not swallow.
        // It exists because `toggle` is the wrong verb for a caller that wants
        // this surface up regardless: the launcher's ">" menu list would
        // otherwise CLOSE whatever was already open when you picked it.
        function open(): void   { root.show(); }
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
                width: root.boxWidth > 0 ? root.boxWidth : Math.round(win.width * root.widthFraction)
                height: root.boxHeight > 0 ? root.boxHeight : Math.round(win.height * root.heightFraction)
                anchors.centerIn: parent
                color: Theme.base
                border.color: Theme.mauve
                border.width: 1
                radius: Theme.borderRadius

                MouseArea { anchors.fill: parent }   // swallow clicks so they don't close

                // Built when the box appears on this output, destroyed when it
                // goes. Ungated, every picker's content existed on every output
                // for the whole session — eighteen trees for the one that can be
                // on screen, and the wallpaper grid held its decoded thumbnails
                // in all three of them.
                //
                // Taking focus and putting the selection on the first row happen
                // here because a picker that forgets either is simply a dead
                // keyboard; `reset()` is left to mean "my own extra state".
                Loader {
                    id: loader
                    active: boxFrame.visible
                    anchors.fill: parent
                    anchors.margins: boxFrame.border.width
                    sourceComponent: root.box
                    onLoaded: {
                        root.selected = root.firstSelectable();
                        item.forceActiveFocus();
                        if (item.reset) item.reset();
                    }
                }
            }
        }
    }
}
