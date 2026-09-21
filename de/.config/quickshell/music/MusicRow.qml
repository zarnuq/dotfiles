pragma ComponentBehavior: Bound
import QtQuick
// Parent import: `Txt` (and the root singletons) live one level up. A QML
// file does NOT see its parent directory implicitly — only its own.
import ".."

// One row in a browse pane. The queue draws its own (four aligned columns and a
// marked state); the other four tabs all want this shape.
Item {
    id: root

    required property MusicList list
    required property int index
    property string icon: ""
    property string label: ""
    property string detail: ""
    property color iconColor: Theme.overlay0
    // Stays visible under the cursor rather than being covered by it.
    property bool current: false

    readonly property bool sel: root.index === root.list.cursor
    readonly property int detailWidth: root.detail === "" ? 0 : root.list.s(190)
    function fs(n) { return Math.round(root.list.s(n) * root.list.fontScale); }

    width: root.list.width
    height: root.list.rowH

    signal activated()

    Rectangle {
        anchors.fill: parent
        visible: root.sel || root.current
        color: root.current
               ? Qt.rgba(Theme.mauve.r, Theme.mauve.g, Theme.mauve.b, root.sel ? 0.22 : 0.12)
               : Theme.rowSelectBg
    }

    Rectangle {
        anchors.left: parent.left
        width: root.list.s(3)
        height: parent.height
        visible: root.current
        color: Theme.mauve
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: root.list.s(12)
        anchors.rightMargin: root.list.s(12)
        spacing: root.list.s(10)

        Txt {
            width: root.list.s(20)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: root.fs(13)
            color: root.iconColor
            text: root.icon
        }
        Txt {
            width: parent.width - root.list.s(20) - root.list.s(20) - root.detailWidth
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.pixelSize: root.fs(13)
            color: root.current ? Theme.mauve
                   : root.sel ? Theme.rowSelectFg : Theme.text
            text: root.label
        }
        Txt {
            width: root.detailWidth
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.pixelSize: root.fs(12)
            color: Theme.overlay0
            text: root.detail
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: event => {
            if (root.list.allowHover(hover, event)) root.list.cursor = root.index;
        }
        onClicked: root.list.cursor = root.index
        onDoubleClicked: { root.list.cursor = root.index; root.activated(); }
    }
}
