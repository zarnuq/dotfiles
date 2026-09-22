pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Shared browse list for the non-queue tabs: virtualized rows, keyboard cursor,
// hover guard. The queue keeps its own incremental row model because it is
// edited underneath the user; these panes replace their content wholesale on
// navigation, so a plain array model is both adequate and correct.
Item {
    id: root

    property var rows: []
    property int cursor: 0
    property Component rowDelegate: null
    property string emptyText: "nothing here"
    property bool busy: false

    readonly property int count: root.rows.length
    readonly property int viewportRows: Math.max(1, Math.floor(list.height / Ui.rowH))
    readonly property var current: root.cursor >= 0 && root.cursor < root.count
                                   ? root.rows[root.cursor] : null

    signal activated(int index)

    function moveTo(i) {
        if (root.count > 0) root.cursor = Math.max(0, Math.min(root.count - 1, i));
    }
    function moveBy(delta) { root.moveTo(root.cursor + delta); }
    function reveal() { list.positionViewAtIndex(root.cursor, ListView.Contain); }

    // A fresh list starts at its beginning; that is the point of descending.
    function resetCursor() {
        root.cursor = 0;
        list.positionViewAtBeginning();
    }

    onCursorChanged: root.reveal()

    // rmpc's navigation half. Returns true when consumed, so a pane adds only
    // its own keys on top.
    function navKey(event) {
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        switch (event.key) {
        case Qt.Key_J: if (!shift) { root.moveBy(1); return true; } break;
        case Qt.Key_K: if (!shift) { root.moveBy(-1); return true; } break;
        case Qt.Key_G: root.moveTo(shift ? root.count - 1 : 0); return true;
        case Qt.Key_D: if (ctrl) { root.moveBy(Math.floor(root.viewportRows / 2)); return true; } break;
        case Qt.Key_U: if (ctrl) { root.moveBy(-Math.floor(root.viewportRows / 2)); return true; } break;
        case Qt.Key_Return:
        case Qt.Key_Enter: if (root.current) root.activated(root.cursor); return true;
        }
        return false;
    }

    // A new list must not inherit the old one's pointer baseline.
    onRowsChanged: Ui.resetHover()

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: root.rows
        currentIndex: root.cursor
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 0
        delegate: root.rowDelegate

        MusicScrollBar { view: list }
    }

    Txt {
        anchors.centerIn: parent
        visible: root.count === 0
        color: Theme.surface1
        font.pixelSize: Ui.fs(13)
        text: root.busy ? "loading…" : root.emptyText
    }
}
