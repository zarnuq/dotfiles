pragma ComponentBehavior: Bound
import QtQuick

// The query row of a picker that filters as you type (the launcher and the
// clipboard picker): the entry, its placeholder, and the keys every such
// picker shares.
//
// Every navigation key is handled here because the field keeps focus the whole
// time — bare j/k belong to the query, so Picker.navKey can't be used; the list
// is walked with the arrows or Ctrl+j/k instead. Return is `submitted` (the
// caller reads the modifiers off the event), and whatever else is pressed goes
// to `extraKey`, where setting `event.accepted` claims it before the field
// types it.
Item {
    id: root

    required property Picker picker
    property alias text: field.text
    required property int margin
    required property int fontSize

    property string placeholder: ""
    property bool placeholderShown: field.text === ""

    signal submitted(var event)
    signal extraKey(var event)

    // The box is rebuilt each time it appears, but Picker hands focus to the
    // box's root first, so the field has to take it back.
    function reset(): void { field.text = ""; field.forceActiveFocus(); }

    Field {
        id: field
        anchors.fill: parent
        anchors.leftMargin: root.margin
        anchors.rightMargin: root.margin
        font.pixelSize: root.fontSize
        focus: true

        Keys.onPressed: function (e) {
            var ctrl = e.modifiers & Qt.ControlModifier;
            if (e.key === Qt.Key_Escape) root.picker.hide();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.submitted(e);
            else if (e.key === Qt.Key_Down || (e.key === Qt.Key_J && ctrl)) root.picker.move(1);
            else if (e.key === Qt.Key_Up || (e.key === Qt.Key_K && ctrl)) root.picker.move(-1);
            else { root.extraKey(e); return; }
            e.accepted = true;
        }
    }

    // A placeholder that stays up once something is typed (the launcher's
    // lone "/") has to start AFTER the text and its cursor instead of on top
    // of them.
    Txt {
        anchors.fill: parent
        anchors.leftMargin: root.margin + (field.text === "" ? 0 : field.contentWidth + 10)
        anchors.rightMargin: root.margin
        verticalAlignment: Text.AlignVCenter
        visible: root.placeholderShown
        text: root.placeholder
        color: Theme.subtext0
        font.pixelSize: root.fontSize
    }
}
