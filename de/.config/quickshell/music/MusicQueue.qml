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

    delegate: Item {
        id: row
        required property int index
        readonly property var modelData: root.controller.queue[index] || root.emptyRow
        width: root.width
        height: Ui.rowH

        readonly property bool isCurrent: root.controller.client.songId >= 0
                                          && parseInt(modelData.Id) === root.controller.client.songId
        readonly property bool isCursor: index === root.controller.cursor
        readonly property bool isMarked: root.controller.isMarked(modelData)
        readonly property bool isMatch: root.controller.query !== "" && root.controller.matches(index)
        Rectangle {
            anchors.fill: parent
            visible: row.isCursor || row.isCurrent || row.isMarked
            color: row.isCurrent
                   ? Qt.rgba(Theme.mauve.r, Theme.mauve.g, Theme.mauve.b, row.isCursor ? 0.22 : 0.12)
                   : row.isMarked
                     ? Qt.rgba(Theme.blue.r, Theme.blue.g, Theme.blue.b, row.isCursor ? 0.24 : 0.10)
                     : Theme.rowSelectBg
        }

        Rectangle {
            anchors.left: parent.left
            width: Ui.s(3); height: parent.height
            visible: row.isCurrent
            color: Theme.mauve
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Ui.s(12)
            anchors.rightMargin: Ui.s(12)
            spacing: Ui.s(10)

            Txt {
                width: Ui.s(46)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                font.pixelSize: Ui.fs(12)
                color: row.isMarked ? Theme.blue : Theme.surface1
                text: row.isMarked ? "󰄲" : (row.index + 1)
            }
            Txt {
                width: parent.width - Ui.s(46) - Ui.s(160) - Ui.s(190)
                       - Ui.s(50) - Ui.s(40)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                font.pixelSize: Ui.fs(13)
                font.bold: row.isCurrent
                color: row.isMatch ? Theme.yellow
                       : row.isCurrent ? Theme.mauve
                       : row.isCursor ? Theme.rowSelectFg : Theme.text
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

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: function (e) {
                if (Ui.allowHover(hover, e)) root.controller.cursor = row.index;
            }
            onClicked: root.controller.cursor = row.index
            onDoubleClicked: { root.controller.cursor = row.index; root.controller.playSelected(); }
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
