pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// The palette + shared tokens — the one place every widget reads its colours
// from. Colours come from theme-set's palette.json (Catppuccin key names; plain
// Mocha, or the wallpaper's colours via matugen) and follow it live. Each
// fallback is the Mocha value, used until theme-set has run once.
Singleton {
    id: root

    // An initial binding (blockLoading) so the first frame is already themed;
    // later changes land through onLoaded, which replaces the binding.
    property var p: root.parse(paletteFile.text())

    function parse(t) {
        if (!t) return ({});
        try {
            var parsed = JSON.parse(t);
            if (parsed && typeof parsed === "object") return parsed;
        } catch (e) {
            console.warn("Theme: ignoring unparseable palette: " + e);
        }
        return ({});
    }

    FileView {
        id: paletteFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/theme/palette.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.p = root.parse(text())
    }

    readonly property color base:     root.p.base     ?? "#1e1e2e"
    readonly property color surface0: root.p.surface0 ?? "#313244"
    readonly property color surface1: root.p.surface1 ?? "#45475a"
    readonly property color text:     root.p.text     ?? "#cdd6f4"
    readonly property color subtext0: root.p.subtext0 ?? "#a6adc8"
    readonly property color blue:     root.p.blue     ?? "#89b4fa"
    readonly property color green:    root.p.green    ?? "#a6e3a1"
    readonly property color teal:     root.p.teal     ?? "#94e2d5"
    readonly property color peach:    root.p.peach    ?? "#fab387"
    readonly property color red:      root.p.red      ?? "#f38ba8"
    readonly property color mauve:    root.p.mauve    ?? "#cba6f7"
    readonly property color lavender: root.p.lavender ?? "#b4befe"
    readonly property color yellow:   root.p.yellow   ?? "#f9e2af"
    readonly property color crust:    root.p.crust    ?? "#11111b"
    readonly property color subtext1: root.p.subtext1 ?? "#bac2de"
    readonly property color overlay0: root.p.overlay0 ?? "#6c7086"   // recessive text: a third rank under subtext0
    readonly property color overlay1: root.p.overlay1 ?? "#7f849c"   // the bar's unselected desktop labels

    // The selected row in a picker list: a flat dark band, and a label lifted
    // just off the normal text colour. Named because four pickers were each
    // spelling the same two hex values out by hand.
    readonly property color rowSelectBg: crust
    readonly property color rowSelectFg: subtext1

    // The focused desktop's label on the bar, on mauve: plain white under Mocha
    // (carried over from reach's own bar), matugen's on_primary otherwise — a
    // wallpaper accent can be light enough that white vanishes on it.
    readonly property color barSelectFg: root.p.onAccent ?? "#ffffff"

    /// `c` at opacity `a` — a palette colour as a wash rather than a new token.
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // The current device / playing song: a mauve wash that brightens under the
    // cursor instead of being covered by the selection band. PickerRow and the
    // music player's rows both draw it, so the two strengths live here.
    function currentWash(selected) { return root.alpha(root.mauve, selected ? 0.22 : 0.12); }

    // The dimming laid over the whole screen around Spotlight's hole: plain
    // black at partial opacity, so it darkens whatever is under it without
    // tinting it.
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.55)

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int borderRadius: 0   // flat/sharp everywhere
}
