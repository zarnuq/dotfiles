pragma ComponentBehavior: Bound
import QtQuick

// The box of a type-to-filter picker (Keybinds, Processes, ClipboardPicker):
// the query row, a divider, the caller's results filling the middle, and the
// footer. Children are the middle; fill it with `anchors.fill: parent`.
Column {
    id: root

    required property Picker picker
    property alias placeholder: search.placeholder
    property alias status: footer.status
    property alias hint: footer.hint
    default property alias content: body.data

    signal submitted(var event)
    signal extraKey(var event)

    spacing: 0

    function reset(): void { search.reset(); }

    PickerSearch {
        id: search
        picker: root.picker
        width: parent.width
        height: root.picker.s(46)
        onSubmitted: e => root.submitted(e)
        onExtraKey: e => root.extraKey(e)
    }

    Rectangle { width: parent.width; height: 1; color: Theme.surface1 }

    Item {
        id: body
        width: parent.width
        height: root.height - search.height - footer.height - 1
    }

    PickerFooter {
        id: footer
        picker: root.picker
    }
}
