pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

// Catppuccin Mocha palette + shared tokens — the one source of truth every
// widget reads its colours from.
Singleton {
    id: root
    readonly property color base:     "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color text:     "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color blue:     "#89b4fa"
    readonly property color green:    "#a6e3a1"
    readonly property color teal:     "#94e2d5"
    readonly property color peach:    "#fab387"
    readonly property color red:      "#f38ba8"
    readonly property color mauve:    "#cba6f7"
    readonly property color lavender: "#b4befe"
    readonly property color yellow:   "#f9e2af"
    readonly property color crust:    "#11111b"
    readonly property color subtext1: "#bac2de"
    readonly property color overlay0: "#6c7086"   // recessive text: a third rank under subtext0
    readonly property color overlay1: "#7f849c"   // the bar's unselected desktop labels

    // The selected row in a picker list: a flat dark band, and a label lifted
    // just off the normal text colour. Named because four pickers were each
    // spelling the same two hex values out by hand.
    readonly property color rowSelectBg: crust
    readonly property color rowSelectFg: subtext1

    // The focused desktop's label on the bar: plain white on mauve, carried
    // over from reach's own bar (config.zon `.bar`) — not a palette colour.
    readonly property color barSelectFg: "#ffffff"

    readonly property string font: "JetBrains Mono Nerd Font"
    readonly property int borderRadius: 0   // flat/sharp everywhere
}
