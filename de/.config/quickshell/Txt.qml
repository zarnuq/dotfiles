import QtQuick

// Text with the shell's default font + colour baked in, so widgets only set
// what differs (size / colour / text). Keeps every label a one-liner.
Text {
    font.family: Theme.font
    color: Theme.text
    textFormat: Text.PlainText
}
