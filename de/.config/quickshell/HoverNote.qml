import QtQuick

// Hover tooltip for grid cells whose text has been elided. Drops itself into a
// parent Item and fills it; the note floats above, clamped to stay on-screen.
// Named HoverNote rather than ToolTip so it can never collide with the
// QtQuick.Controls type of that name.
MouseArea {
    id: hn
    property string detail: ""
    property string sub: ""

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton      // never swallow clicks from the cell

    Rectangle {
        id: note
        visible: hn.containsMouse && hn.detail !== ""
        z: 100
        parent: hn                    // float above siblings, ignore Column layout
        width: Math.min(320, Math.max(noteText.implicitWidth, subText.implicitWidth) + 16)
        height: col.implicitHeight + 12

        // Prefer below-right of the cursor, but flip when that would overflow
        // the window — a tooltip off the edge of the grid is worse than none.
        x: Math.max(-hn.x + 4, Math.min(hn.mouseX + 12, hn.width - width - 2))
        y: hn.mouseY + 22 + height < hn.height ? hn.mouseY + 22 : hn.mouseY - height - 8

        color: Theme.surface0
        border.color: Theme.surface1
        border.width: 1
        radius: Theme.borderRadius

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 2

            Txt {
                id: noteText
                width: parent.width
                text: hn.detail
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
            Txt {
                id: subText
                width: parent.width
                visible: hn.sub !== ""
                text: hn.sub
                font.pixelSize: 10
                color: Theme.subtext0
                wrapMode: Text.WordWrap
            }
        }
    }
}
