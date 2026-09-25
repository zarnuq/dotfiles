pragma ComponentBehavior: Bound
import QtQuick
import ".."

// What every row in the player draws under its cells: the selection band, the
// playing song's mauve wash and accent bar, the queue's blue marked tint, and
// the guarded hover. The queue's five columns (MusicQueue) and the browse
// panes' icon/label/detail (MusicRow) both sit on this, so a row looks the
// same on every tab. Cells go in as children and land in the padded Row.
Item {
    id: root

    property bool selected: false
    // Stays visible under the cursor rather than being covered by it.
    property bool current: false
    property bool marked: false

    default property alias cells: body.data

    // Hover (real movement only — see Ui.allowHover) or a click: take the cursor.
    signal picked()
    signal activated()

    height: Ui.rowH

    Rectangle {
        anchors.fill: parent
        visible: root.selected || root.current || root.marked
        color: root.current
               ? Qt.rgba(Theme.mauve.r, Theme.mauve.g, Theme.mauve.b, root.selected ? 0.22 : 0.12)
               : root.marked
                 ? Qt.rgba(Theme.blue.r, Theme.blue.g, Theme.blue.b, root.selected ? 0.24 : 0.10)
                 : Theme.rowSelectBg
    }

    Rectangle {
        anchors.left: parent.left
        width: Ui.s(3)
        height: parent.height
        visible: root.current
        color: Theme.mauve
    }

    Row {
        id: body
        anchors.fill: parent
        anchors.leftMargin: Ui.s(12)
        anchors.rightMargin: Ui.s(12)
        spacing: Ui.s(10)
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: event => {
            if (Ui.allowHover(hover, event)) root.picked();
        }
        onClicked: root.picked()
        onDoubleClicked: { root.picked(); root.activated(); }
    }
}
