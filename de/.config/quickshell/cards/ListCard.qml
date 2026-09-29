pragma ComponentBehavior: Bound
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// One entry in a card's list (Calendar's events, Notifications' history): a
// flat surface0 slab whose height follows its content. Children go into a
// Column inset `hMargin` from each side, with s(8) above and below; `accent`
// draws a left-edge strip in that colour (Calendar's per-day rainbow).
Rectangle {
    id: root

    property real hMargin: Config.s(8)
    property color accent: "transparent"
    property alias spacing: body.spacing
    default property alias content: body.data

    color: Theme.surface0
    radius: Theme.borderRadius
    implicitHeight: body.height + Config.s(16)

    Rectangle {
        visible: root.accent.a > 0
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Config.s(3)
        color: root.accent
    }

    Column {
        id: body
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                  leftMargin: root.hMargin; rightMargin: root.hMargin }
    }
}
