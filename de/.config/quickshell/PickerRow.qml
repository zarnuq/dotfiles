pragma ComponentBehavior: Bound
import QtQuick

// Shared menu row: the chrome (selection band, current-device wash, section
// label, guarded hover) and the row itself — an icon, a label that takes
// whatever is left, an optional slot for a control, and a right-aligned
// trailing label.
//
// Settings, Audio, Network and the clipboard picker each wrote that Row out by
// hand, and each sized the label by subtracting every other cell's width and
// the spacings from the parent's — four copies of a sum that has to be
// corrected whenever a cell is added or resized. Here the label simply fills.
//
// A control for the slot is declared as a child of the row (the audio mixer's
// volume track, the one thing that isn't a label) and the row is told how wide
// to make room for it with `slotWidth`; everything else is a property. The
// caller still owns the selection colours it cares about and `activated`.
Item {
    id: root

    required property Picker picker
    required property var modelData
    required property int index
    // The picker's, which is what its boxHeight was summed from; a row that
    // isn't in `rows` (the clipboard history) sets its own.
    property int headerHeight: picker.headerHeight
    property int rowHeight: picker.rowHeight
    property bool current: false

    // ── the cells ─────────────────────────────────────────────────────────
    // Children of the row land in the slot between the label and the trailing
    // text, which is the only place a caller has ever needed to put one.
    default property alias slot: slotItem.data

    property int hMargin: Config.s(18)
    property int cellSpacing: Config.s(12)

    property string icon: ""
    property int iconWidth: Config.s(24)
    property int iconSize: Config.s(17)
    property int iconAlign: Text.AlignLeft
    property color iconColor: Theme.subtext0

    property string label: ""
    property int labelSize: Config.s(15)
    property color labelColor: root.sel ? Theme.rowSelectFg : Theme.text

    property int slotWidth: 0

    property string trailing: ""
    property int trailingWidth: 0
    property int trailingSize: Config.s(13)
    property color trailingColor: Theme.subtext0

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
        anchors.leftMargin: root.hMargin
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.s(4)
        text: root.isHeader ? root.modelData.label : ""
        color: Theme.surface1
        font.pixelSize: Config.s(13)
    }

    Row {
        id: cells
        visible: !root.isHeader
        anchors.fill: parent
        anchors.leftMargin: root.hMargin
        anchors.rightMargin: root.hMargin
        spacing: root.cellSpacing

        Txt {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconWidth
            horizontalAlignment: root.iconAlign
            text: root.icon
            color: root.iconColor
            font.pixelSize: root.iconSize
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            // Whatever the other cells leave. A Row gives an invisible child
            // neither width nor spacing, so every term is conditional on the
            // cell being there at all.
            width: cells.width
                   - (root.icon !== "" ? root.iconWidth + cells.spacing : 0)
                   - (root.slotWidth > 0 ? root.slotWidth + cells.spacing : 0)
                   - (root.trailingWidth > 0 ? root.trailingWidth + cells.spacing : 0)
            elide: Text.ElideRight
            text: root.label
            color: root.labelColor
            font.pixelSize: root.labelSize
        }

        Item {
            id: slotItem
            visible: root.slotWidth > 0
            width: root.slotWidth
            height: parent.height
        }

        Txt {
            visible: root.trailingWidth > 0
            anchors.verticalCenter: parent.verticalCenter
            width: root.trailingWidth
            horizontalAlignment: Text.AlignRight
            text: root.trailing
            color: root.trailingColor
            font.pixelSize: root.trailingSize
        }
    }

    PickerHover {
        visible: !root.isHeader
        picker: root.picker
        row: root.index
        onActivated: root.activated()
    }
}
