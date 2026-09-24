import QtQuick
import ".."

// Flat button, the configurator's one piece of repeated chrome. Not in the root
// directory: nothing outside monitors/ uses it, and the shell's other surfaces
// are row-based (PickerRow) rather than button-based.
Rectangle {
    id: root

    property string label: ""
    property bool accent: false
    property bool enabled: true
    signal clicked()

    width: text.implicitWidth + Config.s(24)
    height: Config.s(30)

    color: !root.enabled ? Theme.surface0
         : root.accent ? (hover.hovered ? Theme.lavender : Theme.mauve)
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
