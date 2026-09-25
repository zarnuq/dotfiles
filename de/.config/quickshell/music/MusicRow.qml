pragma ComponentBehavior: Bound
import QtQuick
import ".."

// One row in a browse pane. The queue lays out its own cells (four aligned
// columns and a marked state); the other four tabs all want this shape. The
// band, accent and hover are MusicRowChrome's, shared with the queue.
MusicRowChrome {
    id: root

    required property MusicList list
    required property int index
    property string icon: ""
    property string label: ""
    property string detail: ""
    property color iconColor: Theme.overlay0

    readonly property int detailWidth: root.detail === "" ? 0 : Ui.s(190)

    width: root.list.width
    selected: root.index === root.list.cursor
    onPicked: root.list.cursor = root.index

    Txt {
        width: Ui.s(20)
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Ui.fs(13)
        color: root.iconColor
        text: root.icon
    }
    Txt {
        width: parent.width - Ui.s(20) - Ui.s(20) - root.detailWidth
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        font.pixelSize: Ui.fs(13)
        color: root.current ? Theme.mauve
               : root.selected ? Theme.rowSelectFg : Theme.text
        text: root.label
    }
    Txt {
        width: root.detailWidth
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        font.pixelSize: Ui.fs(12)
        color: Theme.overlay0
        text: root.detail
    }
}
