pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Flat button, the configurator's one piece of repeated chrome. Not in the root
// directory: nothing outside monitors/ uses it, and the shell's other surfaces
// are row-based (PickerRow) rather than button-based.
Rectangle {
    id: root

    property string label: ""
    property bool accent: false
    // An accent button lightens to lavender on hover; the layout bar's active
    // layout turns that off, since it marks a state rather than an action.
    property bool accentHover: true
    property real hPad: Config.s(24)     // left + right, around the label
    readonly property alias hovered: hover.hovered
    signal clicked()

    width: text.implicitWidth + root.hPad
    height: Config.s(30)

    color: !root.enabled ? Theme.surface0
         : root.accent ? (hover.hovered && root.accentHover ? Theme.lavender : Theme.mauve)
         : (hover.hovered ? Theme.surface1 : Theme.surface0)

    Txt {
        id: text
        anchors.centerIn: parent
        text: root.label
        color: !root.enabled ? Theme.overlay0 : (root.accent ? Theme.crust : Theme.text)
        font.pixelSize: Config.s(13)
    }

    HoverHandler { id: hover; enabled: root.enabled }
    TapHandler {
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
