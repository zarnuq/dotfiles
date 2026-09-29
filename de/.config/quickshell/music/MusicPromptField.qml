pragma ComponentBehavior: Bound
import QtQuick
import ".."

// A prompt, then a text field with a placeholder behind it: the Search tab's
// "tag ›", the C-a picker's "name ›" and the queue search's "/". Callers
// place and size this Item; the field itself is `field`, for focus and
// forceActiveFocus(), and its keys arrive as `keyPressed` so each caller keeps
// its own handling (accept the event to stop it, exactly as Keys.onPressed).
Item {
    id: root

    property string prompt: ""
    property color promptColor: Theme.mauve
    property string placeholder: ""
    property int promptSize: Ui.fs(12)
    property int textSize: Ui.fs(13)
    // Where the field starts. Just past the prompt by default; the queue's
    // one-character "/" uses a fixed step instead.
    property real fieldOffset: label.width + Ui.s(8)

    readonly property alias field: input
    property alias text: input.text

    signal keyPressed(var event)

    Txt {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: root.promptSize
        color: root.promptColor
        text: root.prompt
    }

    Field {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.fieldOffset
        font.pixelSize: root.textSize
        Keys.onPressed: event => root.keyPressed(event)

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === "" && root.placeholder !== ""
            color: Theme.surface1
            font.pixelSize: root.textSize
            text: root.placeholder
        }
    }
}
