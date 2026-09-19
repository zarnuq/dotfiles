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

    // Pin to the main screen, falling back to the first output — which on the
    // laptop is the only one there is.
    Component.onCompleted: if (Config.pinScreen) win.screen = Config.pinScreen;

    // Scale lives on Config so the surfaces that aren't cards share it; s() is
    // kept here as a forwarder because every Widget calls it unqualified.
    function s(n) { return Config.s(n); }

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
