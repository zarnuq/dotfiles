pragma ComponentBehavior: Bound
import QtQuick
import ".."

// The one-line strip at the top of a pane — where you are in the tree, which
// playlist is open, what the lyrics belong to. Anchored to the pane's top edge;
// the pane's list hangs off its bottom.
Txt {
    id: root
    anchors { top: parent.top; left: parent.left; right: parent.right }
    anchors.margins: Ui.s(12)
    anchors.bottomMargin: 0
    height: Ui.s(20)
    elide: Text.ElideRight
    font.pixelSize: Ui.fs(12)
    color: Theme.subtext0
}
