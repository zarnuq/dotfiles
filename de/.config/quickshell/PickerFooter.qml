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
    property int count: root.picker.count
    property int selected: root.picker.selected
    property int margin: root.picker.s(12)
    property int fontSize: root.picker.s(11)

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
            anchors.leftMargin: root.margin
            anchors.right: hintTxt.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.status !== "" ? root.status
                  : root.count ? (root.selected + 1) + "/" + root.count : "0/0"
            color: root.status !== "" ? Theme.peach : Theme.surface1
            elide: Text.ElideRight
            font.pixelSize: root.fontSize
        }

        Txt {
            id: hintTxt
            anchors.right: parent.right
            anchors.rightMargin: root.margin
            anchors.verticalCenter: parent.verticalCenter
            text: root.hint
            color: Theme.surface1
            font.pixelSize: root.fontSize
        }
    }
}
