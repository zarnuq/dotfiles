import QtQuick

// The scrolled list of a picker that drives its own results (the launcher and
// the clipboard picker): a ListView that follows `picker.selected`, and the
// line that stands in for it when there is nothing to show. The caller gives
// it the model and a delegate; hover and click belong to the delegate
// (PickerRow, or a PickerHover inside one).
Item {
    id: root

    required property Picker picker
    property alias model: list.model
    property alias delegate: list.delegate

    // Said instead of rendering a blank box — which is otherwise what an
    // empty list looks like, and indistinguishable from a broken one.
    property string emptyText: ""
    required property int emptySize

    Txt {
        anchors.centerIn: parent
        visible: root.picker.count === 0
        text: root.emptyText
        color: Theme.subtext0
        font.pixelSize: root.emptySize
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        currentIndex: root.picker.selected
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        boundsBehavior: Flickable.StopAtBounds
    }
}
