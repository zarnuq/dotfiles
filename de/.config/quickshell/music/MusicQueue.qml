pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Virtualized queue. The incremental row model preserves scroll position on edits.
ListView {
    id: root
    required property MusicController controller
    readonly property int viewportRows: Math.max(1, Math.floor(height / Ui.rowH))
    readonly property var emptyRow: ({})
    clip: true
    model: root.controller.rowModel
    currentIndex: root.controller.cursor
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0
    cacheBuffer: 0
    function reveal() { root.positionViewAtIndex(root.controller.cursor, ListView.Contain); }
    Connections {
        target: root.controller
        function onCursorChanged() { root.reveal(); }
        function onRevealRequested() { Qt.callLater(root.reveal); }
        function onResetRequested() { Ui.resetHover(); }
    }
    Component.onCompleted: root.positionViewAtIndex(root.controller.cursor, ListView.Center)
    MusicScrollBar { view: root }

    delegate: MusicRowChrome {
        id: row
        required property int index
        readonly property var modelData: root.controller.queue[index] || root.emptyRow
        readonly property bool isMatch: root.controller.query !== "" && root.controller.matches(index)
        width: root.width

        current: root.controller.client.songId >= 0
                 && parseInt(modelData.Id) === root.controller.client.songId
        selected: index === root.controller.cursor
        marked: root.controller.isMarked(modelData)
        onPicked: root.controller.cursor = row.index
        onActivated: root.controller.playSelected()

        Txt {
            width: Ui.s(46)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Ui.fs(12)
            color: row.marked ? Theme.blue : Theme.surface1
            text: row.marked ? "󰄲" : (row.index + 1)
        }
        Txt {
            width: parent.width - Ui.s(46) - Ui.s(160) - Ui.s(190)
                   - Ui.s(50) - Ui.s(40)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.pixelSize: Ui.fs(13)
            font.bold: row.current
            color: row.isMatch ? Theme.yellow
                   : row.current ? Theme.mauve
                   : row.selected ? Theme.rowSelectFg : Theme.text
            text: root.controller.client.songTitle(row.modelData)
        }
        Txt {
            width: Ui.s(160)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.pixelSize: Ui.fs(12)
            color: Theme.subtext0
            text: row.modelData.Artist || ""
        }
        Txt {
            width: Ui.s(190)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.pixelSize: Ui.fs(12)
            color: Theme.overlay0
            text: row.modelData.Album || ""
        }
        Txt {
            width: Ui.s(50)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Ui.fs(12)
            color: Theme.overlay0
            text: root.controller.client.fmtTime(parseFloat(row.modelData.duration || row.modelData.Time || 0))
        }
    }

    Txt {
        anchors.centerIn: parent
        visible: root.controller.queue.length === 0
        color: Theme.surface1
        font.pixelSize: Ui.fs(13)
        text: root.controller.client.connected ? "queue is empty" : "connecting to mpd…"
    }
}
