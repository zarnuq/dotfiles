import Quickshell
import QtQuick

// The switchboard's UI: every feature in Config.features with a checkbox.
// `Super+Shift+Escape` / `qs ipc call settings toggle`.
//
// This exists so one stowed quickshell config can serve several machines: what
// a box has turned off lives in ~/.local/state/quickshell/features.json, which
// is outside the repo and therefore never committed or stowed. Toggling writes
// that file and flips the LazyLoader in shell.qml in the same frame, so a
// feature appears or disappears as you press space — no restart.
Picker {
    id: root

    ipcTarget: "settings"
    allScreens: false

    readonly property real scale: Config.scale
    function s(n) { return Config.s(n); }

    readonly property int headerHeight: s(28)
    readonly property int rowHeight: s(34)
    readonly property int footerHeight: s(30)

    // Headers are inserted where the group changes, so the catalogue stays a
    // flat list and the menu structure falls out of its order.
    rows: {
        var r = [];
        var group = "";
        for (var i = 0; i < Config.features.length; i++) {
            var f = Config.features[i];
            if (f.group !== group) { group = f.group; r.push({ kind: "header", label: group }); }
            r.push({ kind: "feature", key: f.key, label: f.label });
        }
        return r;
    }

    boxWidth: s(420)
    boxHeight: {
        var h = s(12) * 2 + footerHeight;
        for (var i = 0; i < rows.length; i++)
            h += rows[i].kind === "header" ? headerHeight : rowHeight;
        return h;
    }

    function toggleRow(i) {
        if (!selectable(i)) return;
        Config.toggle(rows[i].key);
    }

    box: Component {
        Item {
            id: content
            focus: true

            function reset() { root.selected = root.firstSelectable(); content.forceActiveFocus(); }

            Keys.onPressed: function (e) {
                var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier));
                if (e.key === Qt.Key_Escape) { root.hide(); }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                    root.toggleRow(root.selected);
                } else if (e.key === Qt.Key_Down || (e.key === Qt.Key_J && (plain || (e.modifiers & Qt.ControlModifier)))) {
                    root.move(1);
                } else if (e.key === Qt.Key_Up || (e.key === Qt.Key_K && (plain || (e.modifiers & Qt.ControlModifier)))) {
                    root.move(-1);
                } else { return; }
                e.accepted = true;
            }

            Column {
                anchors.fill: parent
                anchors.topMargin: root.s(12)
                spacing: 0

                Repeater {
                    model: root.rows

                    Item {
                        id: rowItem
                        required property var modelData
                        required property int index
                        readonly property bool isHeader: modelData.kind === "header"
                        readonly property bool enabled_: !isHeader && Config.on(modelData.key)
                        readonly property bool sel: index === root.selected

                        width: content.width
                        height: isHeader ? root.headerHeight : root.rowHeight

                        Rectangle {
                            anchors.fill: parent
                            visible: rowItem.sel
                            color: Theme.rowSelectBg
                        }

                        Txt {
                            visible: rowItem.isHeader
                            anchors.left: parent.left
                            anchors.leftMargin: root.s(18)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: root.s(4)
                            text: rowItem.isHeader ? rowItem.modelData.label : ""
                            color: Theme.surface1
                            font.pixelSize: root.s(13)
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            visible: !rowItem.isHeader
                            hoverEnabled: true
                            onPositionChanged: function (e) { if (root.hoverMoved(hover, e)) root.selected = rowItem.index; }
                            onClicked: { root.selected = rowItem.index; root.toggleRow(rowItem.index); }
                        }

                        Row {
                            visible: !rowItem.isHeader
                            anchors.fill: parent
                            anchors.leftMargin: root.s(18)
                            anchors.rightMargin: root.s(18)
                            spacing: root.s(12)

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.s(20)
                                text: rowItem.enabled_ ? "󰄲" : "󰄱"
                                color: rowItem.enabled_ ? Theme.mauve : Theme.surface1
                                font.pixelSize: root.s(17)
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: rowItem.isHeader ? "" : rowItem.modelData.label
                                color: !rowItem.enabled_ ? Theme.surface1
                                       : rowItem.sel ? Theme.rowSelectFg : Theme.text
                                font.pixelSize: root.s(15)
                            }
                        }
                    }
                }

                // Where the answer lives, so a machine's odd behaviour is
                // traceable to a file rather than to the config in git.
                Item {
                    width: parent.width
                    height: root.footerHeight

                    Txt {
                        anchors.centerIn: parent
                        text: "space toggles · saved to " + Config.statePath.replace(Quickshell.env("HOME"), "~")
                        color: Theme.surface1
                        font.pixelSize: root.s(11)
                    }
                }
            }
        }
    }
}
