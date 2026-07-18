import Quickshell
import Quickshell.Wayland
import QtQuick

// Base window for every eww-style widget.
//
// Handles the boilerplate that was identical across all eww `defwindow`s:
//   - pin to DP-2 (eww :monitor 1)
//   - per-screen scale + s() helper (mirrors the runit service: DP-2 -> 1.0, else 0.85)
//   - background layer + no exclusive zone
//   - the flat card chrome (base bg, surface0 border, radius 0, padded)
//
// An instance just sets anchors / margins / implicit size and drops its
// content inside; content is laid into the padded card automatically.
PanelWindow {
    id: win

    default property alias content: body.data
    property int pad: 10                     // inner padding, unscaled (s() applied)
    property color bg: Theme.base
    property color borderColor: Theme.surface0
    property int stackLayer: WlrLayer.Bottom // eww "bottom"; tray overrides to Overlay

    // Pin to DP-2, falling back to the first screen if it's absent.
    Component.onCompleted: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === "DP-2") { win.screen = Quickshell.screens[i]; return; }
        if (Quickshell.screens.length > 0)
            win.screen = Quickshell.screens[0];
    }
    property real scale: (screen && screen.name === "DP-2") ? 1.0 : 0.85
    function s(n) { return Math.round(n * scale); }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: stackLayer

    Rectangle {
        anchors.fill: parent
        color: win.bg
        border.color: win.borderColor
        border.width: win.s(1)
        radius: Theme.borderRadius

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: win.s(win.pad)
        }
    }
}
