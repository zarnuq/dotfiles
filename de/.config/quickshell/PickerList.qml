pragma ComponentBehavior: Bound
import QtQuick

// The body of a list picker: the keyboard, the column of rows, and the bottom
// bar. Settings, Audio and Network each opened with the same fifteen lines —
// take focus, offer every key to Picker.navKey first, then a Column of
// PickerRows over `picker.rows` — and each padded the box a little differently.
//
// The caller supplies `rowDelegate` (a PickerRow, which the Repeater hands
// `modelData` and `index`) and the bottom bar: either `hint` (the keys, dim)
// and `status` (an action's progress or error, peach, shown over the hint), or
// as children, whatever else the bar draws.
// `extraKey` carries the keys navKey didn't take; setting `event.accepted` in
// that handler is what claims one.
Item {
    id: root

    required property Picker picker
    property Component rowDelegate: null

    // The bar is anchored, not the last item in the Column, so a list that
    // grows can never push it out of the box; Picker.boxHeight already
    // reserves `barHeight` for it.
    default property alias bar: barItem.data
    property string hint: ""
    property string status: ""

    // Called by Picker when the box appears, after it has taken focus and put
    // the selection on the first row — so this means only "my own extra state"
    // (a query to clear, a password field to drop).
    signal resetting()
    function reset(): void { root.resetting(); }

    signal extraKey(var event)

    focus: true
    Keys.onPressed: function (e) {
        if (root.picker.navKey(e)) return;
        root.extraKey(e);
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.picker.s(12)
        spacing: 0

        Repeater {
            model: root.picker.rows
            delegate: root.rowDelegate
        }
    }

    Item {
        id: barItem
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.picker.s(18)
        anchors.rightMargin: root.picker.s(18)
        anchors.bottomMargin: root.picker.s(12)
        height: root.picker.barHeight

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: text !== ""
            text: root.status !== "" ? root.status : root.hint
            color: root.status !== "" ? Theme.peach : Theme.surface1
            elide: Text.ElideRight
            font.pixelSize: root.picker.s(13)
        }
    }
}
