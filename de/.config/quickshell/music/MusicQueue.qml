pragma ComponentBehavior: Bound
import QtQuick
// Parent import: `Txt` (and the root singletons) live one level up. A QML
// file does NOT see its parent directory implicitly — only its own.
import ".."

// Virtualized queue. The incremental row model preserves scroll position on edits.
ListView {
    id: root
    required property MusicController controller
    property real fontScale: 1.2
    function s(n) { return Config.s(n); }
    function fs(n) { return Math.round(root.s(n) * root.fontScale); }
    readonly property int rowH: root.s(31)
    readonly property int viewportRows: Math.max(1, Math.floor(height / root.rowH))
    readonly property var emptyRow: ({})

    // Compare window coordinates so scrolling under a stationary pointer
    // cannot move the cursor. The first event after reset only sets a baseline.
    property point lastPointer: Qt.point(-1, -1)
    property bool pointerSeen: false
    function allowHover(item, event) {
        var point = item.mapToItem(null, event.x, event.y);
        var moved = root.pointerSeen && (Math.abs(point.x - root.lastPointer.x) >= 1
                                        || Math.abs(point.y - root.lastPointer.y) >= 1);
        root.pointerSeen = true;
        root.lastPointer = point;
        return moved;
    }
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
        function onResetRequested() { root.pointerSeen = false; }
    }
    Component.onCompleted: root.positionViewAtIndex(root.controller.cursor, ListView.Center)
    Rectangle {
        anchors.right: parent.right
        width: root.s(2)
        color: Theme.surface1
        visible: root.contentHeight > root.height
        y: root.contentHeight > 0
           ? root.visibleArea.yPosition * root.height : 0
        height: root.contentHeight > 0
                ? Math.max(root.s(20), root.visibleArea.heightRatio * root.height) : 0
    }

    delegate: Item {
        id: row
        required property int index
        readonly property var modelData: root.controller.queue[index] || root.emptyRow
        width: root.width
        height: root.rowH

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
            width: root.s(3); height: parent.height
            visible: row.isCurrent
            color: Theme.mauve
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: root.s(12)
            anchors.rightMargin: root.s(12)
            spacing: root.s(10)

            Txt {
                width: root.s(46)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                font.pixelSize: root.fs(12)
                color: row.isMarked ? Theme.blue : Theme.surface1
                text: row.isMarked ? "󰄲" : (row.index + 1)
            }
            Txt {
                width: parent.width - root.s(46) - root.s(160) - root.s(190)
                       - root.s(50) - root.s(40)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                font.pixelSize: root.fs(13)
                font.bold: row.isCurrent
                color: row.isMatch ? Theme.yellow
                       : row.isCurrent ? Theme.mauve
                       : row.isCursor ? Theme.rowSelectFg : Theme.text
                text: root.controller.client.songTitle(row.modelData)
            }
            Txt {
                width: root.s(160)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                font.pixelSize: root.fs(12)
                color: Theme.subtext0
                text: row.modelData.Artist || ""
            }
            Txt {
                width: root.s(190)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                font.pixelSize: root.fs(12)
                color: Theme.overlay0
                text: row.modelData.Album || ""
            }
            Txt {
                width: root.s(50)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                font.pixelSize: root.fs(12)
                color: Theme.overlay0
                text: root.controller.client.fmtTime(parseFloat(row.modelData.duration || row.modelData.Time || 0))
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: function (e) {
                if (root.allowHover(hover, e)) root.controller.cursor = row.index;
            }
            onClicked: root.controller.cursor = row.index
            onDoubleClicked: { root.controller.cursor = row.index; root.controller.playSelected(); }
        }
    }

    Txt {
        anchors.centerIn: parent
        visible: root.controller.queue.length === 0
        color: Theme.surface1
        font.pixelSize: root.fs(13)
        text: root.controller.client.connected ? "queue is empty" : "connecting to mpd…"
    }
}
