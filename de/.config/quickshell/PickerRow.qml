import QtQuick

// Shared menu row chrome. The caller supplies its content and activation;
// selection, section labels and the current-device highlight stay consistent.
Item {
    id: root

    required property Picker picker
    required property var modelData
    required property int index
    property int headerHeight: Config.s(28)
    property int rowHeight: Config.s(34)
    property bool current: false

    readonly property bool isHeader: modelData.kind === "header"
    readonly property bool sel: index === picker.selected
    height: isHeader ? headerHeight : rowHeight

    signal activated()

    // A current device remains visible while another row is selected, and
    // its wash brightens when selected instead of disappearing under a band.
    Rectangle {
        anchors.fill: parent
        visible: root.sel || root.current
        color: root.current
               ? Qt.rgba(Theme.mauve.r, Theme.mauve.g, Theme.mauve.b, root.sel ? 0.22 : 0.12)
               : Theme.rowSelectBg
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.current
        width: Config.s(3)
        height: parent.height
        color: Theme.mauve
    }

    Txt {
        visible: root.isHeader
        anchors.left: parent.left
        anchors.leftMargin: Config.s(18)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.s(4)
        text: root.isHeader ? root.modelData.label : ""
        color: Theme.surface1
        font.pixelSize: Config.s(13)
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        visible: !root.isHeader
        hoverEnabled: true
        // Mapping or scrolling a row under a stationary cursor must not
        // steal keyboard selection. Picker compares window-space positions.
        onPositionChanged: function (e) {
            if (root.picker.hoverMoved(hover, e)) root.picker.selected = root.index;
        }
        onClicked: {
            root.picker.selected = root.index;
            root.activated();
        }
    }
}
