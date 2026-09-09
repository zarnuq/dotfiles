import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// "Where is my cursor" — the screen dims and a clear circle stays around the
// pointer (PowerToys' Find My Mouse). Replaces reach's shake-to-grow-the-cursor,
// which reach now only *detects*: it spawns `qs ipc call spotlight show` and
// this file does the rest.
//
// WHY THIS LIVES HERE AND NOT IN REACH: reach is river's window-management
// client, not the compositor, so it has nothing to paint on — and it does not
// know where the cursor is. Its own shake detector reads raw evdev deltas
// precisely because `river_seat_v1.pointer_position` only arrives inside a
// manage sequence (src/shake.zig). Deltas are enough for "is it shaking"; they
// are not enough to draw at the cursor.
//
// No Wayland client can ask for the pointer position either. The only way to
// learn it is to have a surface UNDER the pointer that accepts input — the
// enter event carries surface-local coordinates. That is the whole design
// constraint here, and it is why the effect must be transient: while this is
// mapped it swallows clicks, exactly as Picker.qml's overlays do.
//
// DRAWING, under QT_QUICK_BACKEND=software: no ShaderEffect or layer.effect to
// punch a hole with. Four plain Rectangles cover everything outside a square
// around the cursor, and a single small Canvas covers that square with the dark
// wash and a feathered circle cut out of it.
//
// The Canvas image does not depend on WHERE the cursor is, only on how big the
// hole is. So while the shadow is closing it repaints once per frame, and the
// moment it settles it stops: from then on the pointer only ever MOVES it, and
// nothing repaints a screen of pixels on the CPU as you travel.
//
// The repaint is affordable because the circle is inscribed in the square — the
// Canvas is exactly as big as the hole, never as big as the screen. The costly
// frames are the wide ones at the very start, and OutCubic leaves those almost
// immediately.
Scope {
    id: root

    // Where the hole settles, and where it starts before closing onto the
    // pointer. `curR` is what everything actually reads.
    readonly property int radius: Config.s(95)
    readonly property int openRadius: Config.s(320)
    property real curR: radius

    readonly property color shade: Qt.rgba(0, 0, 0, 0.55)

    // The shadow closes in rather than snapping to size: a ring of dark
    // contracting onto the cursor is what makes the eye find it, which is the
    // entire point of the effect. OutCubic both looks right — quick, then
    // settling — and passes through the wide, expensive radii fastest.
    NumberAnimation {
        id: closing
        target: root
        property: "curR"
        from: root.openRadius
        to: root.radius
        duration: 420
        easing.type: Easing.OutCubic
    }

    property bool shown: false
    property string activeScreen: ""

    // Where the hole goes, in the active output's coordinates.
    property real cx: 0
    property real cy: 0

    function show() {
        root.activeScreen = "";
        root.moved = 0;
        root.shown = true;
        closing.restart();
        grace.restart();
        safety.restart();
    }
    function hide() {
        root.shown = false;
        // Leave the radius settled, so a hidden overlay never holds a huge
        // canvas and the next show() starts from `from` regardless.
        closing.stop();
        root.curR = root.radius;
    }
    function toggle() { if (root.shown) root.hide(); else root.show(); }

    // `flash`/`dismiss`, not show/hide: `qs ipc call <target> show` collides
    // with the `qs ipc show` subcommand and never reaches the handler — the CLI
    // just prints the target listing and exits 0.
    IpcHandler {
        target: "spotlight"
        function flash(): void   { root.show(); }
        function dismiss(): void { root.hide(); }
        function toggle(): void  { root.toggle(); }
    }

    // Dismissing on pointer movement can't start immediately: the gesture that
    // asks for this IS the pointer moving, so the shake that summoned the
    // spotlight would also dismiss it in the same frame.
    property bool armed: false
    property real moved: 0
    Timer { id: grace; interval: 600; onTriggered: root.armed = true }
    onShownChanged: if (!shown) { root.armed = false; grace.stop(); safety.stop(); }

    // Nothing may leave an input-grabbing overlay on screen indefinitely.
    Timer { id: safety; interval: 4000; onTriggered: root.hide() }

    function onPointer(x, y, screenName) {
        if (root.activeScreen === "") root.activeScreen = screenName;
        if (screenName !== root.activeScreen) return;

        if (root.armed) {
            root.moved += Math.abs(x - root.cx) + Math.abs(y - root.cy);
            if (root.moved > Config.s(60)) { root.hide(); return; }
        }
        root.cx = x;
        root.cy = y;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.shown

            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-spotlight"
            // Every output dims, but only the one holding the pointer gets the
            // hole — so the desktop darkens as a whole, the way PowerToys does.
            anchors { top: true; bottom: true; left: true; right: true }

            // Any key dismisses. Only the pointer's output takes the keyboard:
            // reach grants focus to every layer surface it can, and several
            // surfaces each acting on the same keystroke is the bug Picker.qml
            // documents.
            WlrLayershell.keyboardFocus: (root.shown && win.modelData.name === root.activeScreen)
                                         ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: function (e) { root.hide(); e.accepted = true; }
            }

            readonly property bool holed: win.modelData.name === root.activeScreen
            // Rounded for the same reason hx/hy are: this sets the square's size,
            // so a fractional value puts two translucent edges in one pixel.
            readonly property int r: Math.round(root.curR)
            // Clamped so the square never hangs off the edge and leaves a
            // dark-free strip the rectangles below can't cover.
            //
            // ROUNDED, and typed int, because the five pieces below must tile the
            // screen with no pixel covered twice. The wash is translucent, so a
            // pixel that gets it from both the Canvas and a neighbouring rectangle
            // comes out at 1-(1-0.55)^2 = 0.80 instead of 0.55 — a hard black
            // hairline. `cx`/`cy` are MouseArea reals, so an unrounded `hx` puts
            // the rectangle's edge and the Canvas's edge inside the SAME pixel
            // column, and the software renderer antialiases both onto it. That
            // drew a one-pixel black line down the side of the hole, running the
            // exact height of the square, whenever the pointer landed on a
            // fractional coordinate. Integers make the seams land between pixels
            // instead of on one.
            readonly property int hx: Math.round(Math.max(0, Math.min(win.width - 2 * r, root.cx - r)))
            readonly property int hy: Math.round(Math.max(0, Math.min(win.height - 2 * r, root.cy - r)))

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                onPositionChanged: e => root.onPointer(e.x, e.y, win.modelData.name)
                onContainsMouseChanged: if (containsMouse && root.activeScreen === "") root.activeScreen = win.modelData.name
                onPressed: root.hide()
            }

            // The wash, as four solid rectangles around the hole's square. Solid
            // colour, so moving them costs no painting at all.
            Rectangle {
                color: root.shade
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: win.holed ? win.hy : parent.height
            }
            Rectangle {
                visible: win.holed
                color: root.shade
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height - win.hy - 2 * win.r
            }
            Rectangle {
                visible: win.holed
                color: root.shade
                x: 0; y: win.hy
                width: win.hx; height: 2 * win.r
            }
            Rectangle {
                visible: win.holed
                color: root.shade
                x: win.hx + 2 * win.r; y: win.hy
                width: parent.width - win.hx - 2 * win.r; height: 2 * win.r
            }

            // ...and the square itself: same wash with a feathered circle cut
            // out of it. destination-out is QPainter's CompositionMode_
            // DestinationOut, so this works with no GPU. Repainted only while
            // the shadow is closing; once `r` settles this is just moved.
            Canvas {
                id: hole
                visible: win.holed
                x: win.hx; y: win.hy
                width: 2 * win.r; height: 2 * win.r

                // A resize invalidates the buffer, but ask explicitly rather
                // than lean on that — a stale frame here is a visible step in
                // the middle of the animation.
                onWidthChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    // Measured off the canvas itself, not off `win.r`: during the
                    // animation the two can disagree for a frame, and a gradient
                    // sized to the wrong radius shows as a hard ring.
                    var R = width / 2;

                    ctx.reset();
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = root.shade;
                    ctx.fillRect(0, 0, width, height);

                    // Soft edge: fully clear to ~80% of the radius, then ramp
                    // back so the circle doesn't end on a hard aliased step.
                    var g = ctx.createRadialGradient(R, R, 0, R, R, R);
                    g.addColorStop(0.0, "rgba(0,0,0,1)");
                    g.addColorStop(0.8, "rgba(0,0,0,1)");
                    g.addColorStop(1.0, "rgba(0,0,0,0)");
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.arc(R, R, R, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }
    }
}
