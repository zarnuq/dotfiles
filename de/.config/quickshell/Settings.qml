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
    barHeight: s(30)

    function activate(i) {
        if (!selectable(i)) return;
        Config.toggle(rows[i].key);
    }

    box: Component {
        PickerList {
            picker: root

            // Space is this menu's Return: a switchboard you walk with j/k
            // wants the same key on every row, not an Enter that launches.
            onExtraKey: function (e) {
                if (e.key !== Qt.Key_Space) return;
                root.activate(root.selected);
                e.accepted = true;
            }

            rowDelegate: PickerRow {
                id: rowItem
                readonly property bool on_: !isHeader && Config.on(modelData.key)

                picker: root
                width: parent.width
                onActivated: root.activate(rowItem.index)

                icon: rowItem.on_ ? "󰄲" : "󰄱"
                iconWidth: root.s(20)
                iconColor: rowItem.on_ ? Theme.mauve : Theme.surface1
                label: rowItem.isHeader ? "" : rowItem.modelData.label
                labelColor: !rowItem.on_ ? Theme.surface1
                            : rowItem.sel ? Theme.rowSelectFg : Theme.text
            }

            // Where the answer lives, so a machine's odd behaviour is
            // traceable to a file rather than to the config in git.
            Txt {
                anchors.centerIn: parent
                text: "space toggles · saved to " + Config.statePath.replace(Quickshell.env("HOME"), "~")
                color: Theme.surface1
                font.pixelSize: root.s(11)
            }
        }
    }
}
