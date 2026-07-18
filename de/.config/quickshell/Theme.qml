pragma Singleton
import Quickshell
import QtQuick

// Catppuccin Mocha palette + shared tokens.
// Mirrors the $vars at the top of eww.scss so widgets read one source of truth.
Singleton {
    readonly property color base:     "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color text:     "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color blue:     "#89b4fa"
    readonly property color green:    "#a6e3a1"
    readonly property color peach:    "#fab387"
    readonly property color red:      "#f38ba8"
    readonly property color mauve:    "#cba6f7"
    readonly property color yellow:   "#f9e2af"

    readonly property string font: "JetBrains Mono Nerd Font"
    readonly property int borderRadius: 0   // flat/sharp everywhere
}
