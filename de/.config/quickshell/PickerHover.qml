pragma ComponentBehavior: Bound
import QtQuick

// Hover and click for one entry of a picker's list: pointing at it selects it,
// clicking selects it and fires `activated`. PickerRow, the launcher's rows and
// the wallpaper tiles each carried this MouseArea, and each re-explained the
// guard below.
//
// positionChanged, NOT entered — and even then only through Picker.hoverMoved.
// Arrowing through a list scrolls it, which slides a different entry under a
// motionless cursor and fires hover on it; every keypress then handed the
// selection straight back to whatever the pointer happened to sit on. Only
// real pointer movement, compared in window space, may take the selection.
MouseArea {
    id: root

    required property Picker picker
    required property int row

    signal activated()

    anchors.fill: parent
    hoverEnabled: true
    onPositionChanged: function (e) {
        if (root.picker.hoverMoved(root, e)) root.picker.selected = root.row;
    }
    onClicked: {
        root.picker.selected = root.row;
        root.activated();
    }
}
