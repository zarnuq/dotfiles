import Quickshell
import Quickshell.Wayland
import QtQuick

// Base window for every eww-style widget.
//
// Handles the boilerplate that was identical across all eww `defwindow`s:
//   - pin to Config.mainScreen (eww :monitor 1)
//   - per-machine scale + s() helper (laptop panel -> 0.85, main PC -> 1.0)
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

    // When set (e.g. one instance per output via Variants), pin to this screen
    // instead of the main-screen default. Lets a widget be cloned onto every monitor.
    property var forceScreen: null

    // Pin to forceScreen if given, else the main screen, falling back to the
    // first output — which on the laptop is the only one there is.
    Component.onCompleted: {
        if (win.forceScreen) { win.screen = win.forceScreen; return; }
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === Config.mainScreen) { win.screen = Quickshell.screens[i]; return; }
        if (Quickshell.screens.length > 0)
            win.screen = Quickshell.screens[0];
    }
    property real scale: Config.onLaptop ? 0.85 : 1.0
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
