pragma ComponentBehavior: Bound
import QtQuick

// TextInput with the shell's font and colour baked in, as Txt is for Text.
// Seven fields (the picker query, the Network password, the lock screen, the
// display configurator's "save as", three in the music player) each restated
// the same three lines; callers now set only size, placement and behaviour.
TextInput {
    id: root
    verticalAlignment: TextInput.AlignVCenter
    color: Theme.text
    font.family: Theme.font
}
