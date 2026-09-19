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
    barHeight: footerHeight

    function activate(i) {
        if (!selectable(i)) return;
        Config.toggle(rows[i].key);
    }

    box: Component {
        Item {
            id: content
            focus: true

            Keys.onPressed: function (e) {
                if (root.navKey(e)) return;
                if (e.key !== Qt.Key_Space) return;
                root.activate(root.selected);      // space is this menu's Return
                e.accepted = true;
            }

            Column {
                anchors.fill: parent
                anchors.topMargin: root.s(12)
                spacing: 0

                Repeater {
                    model: root.rows

                    PickerRow {
                        id: rowItem
                        picker: root
                        readonly property bool enabled_: !isHeader && Config.on(modelData.key)

                        width: content.width
                        headerHeight: root.headerHeight
                        rowHeight: root.rowHeight
                        onActivated: root.activate(rowItem.index)

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
