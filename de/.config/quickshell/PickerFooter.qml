pragma ComponentBehavior: Bound
import QtQuick

// Shared footer bar for pickers with a query and results list (Processes,
// ClipboardPicker): a divider line along the top, count or status on the left,
// and keyboard hints on the right.
Item {
    id: root

    required property Picker picker
    property string status: ""
    property string hint: ""

    width: parent.width
    height: root.picker.s(29)

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.surface1
    }

    Item {
        anchors {
            top: parent.top
            topMargin: 1
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Txt {
            anchors.left: parent.left
            anchors.leftMargin: root.picker.s(12)
            anchors.right: hintTxt.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.status !== "" ? root.status
                  : root.picker.count ? (root.picker.selected + 1) + "/" + root.picker.count : "0/0"
            color: root.status !== "" ? Theme.peach : Theme.surface1
            elide: Text.ElideRight
            font.pixelSize: root.picker.s(11)
        }

        Txt {
            id: hintTxt
            anchors.right: parent.right
            anchors.rightMargin: root.picker.s(12)
            anchors.verticalCenter: parent.verticalCenter
            text: root.hint
            color: Theme.surface1
            font.pixelSize: root.picker.s(11)
        }
    }
}
