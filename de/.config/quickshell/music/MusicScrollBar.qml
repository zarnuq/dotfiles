pragma ComponentBehavior: Bound
import QtQuick
import ".."

// The thin scroll indicator both list implementations draw.
Rectangle {
    id: root
    required property Flickable view

    anchors.right: parent.right
    width: Ui.s(2)
    color: Theme.surface1
    visible: root.view.contentHeight > root.view.height
    y: root.view.contentHeight > 0 ? root.view.visibleArea.yPosition * root.view.height : 0
    height: root.view.contentHeight > 0
            ? Math.max(Ui.s(20), root.view.visibleArea.heightRatio * root.view.height) : 0
}
