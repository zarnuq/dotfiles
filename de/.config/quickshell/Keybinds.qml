pragma ComponentBehavior: Bound
import Quickshell.Io
import QtQuick
import "Keybinds.js" as Keybinds

// Keybind cheatsheet (Super+/ / `qs ipc call keybinds toggle`). Rows come from
// reach's config.zon, re-read on every open, so the sheet can't drift from the
// binds. Parsing lives in Keybinds.js (unit-tested). Type to filter by key,
// action or section name.
Picker {
    id: root

    ipcTarget: "keybinds"
    widthFraction: 0.45
    heightFraction: 0.8
    headerHeight: s(30)
    rowHeight: s(28)

    readonly property string configPath:
        Config.configHome + "/reach/config.zon"

    property var all: []
    readonly property var results: Keybinds.filter(root.all, root.query)
    count: root.results.length

    FileView { id: cfg; path: root.configPath; blockLoading: true; printErrors: false }

    onOpened: { cfg.reload(); root.all = Keybinds.parse(cfg.text()); }

    box: Component {
        PickerQueryBox {
            picker: root
            placeholder: "Keybinds…"
            hint: "from reach/config.zon   esc close"
            onSubmitted: root.hide()

            PickerResults {
                id: list
                picker: root
                anchors.fill: parent
                model: root.results
                emptyText: root.all.length === 0 ? "no .binds in " + root.configPath : "no matches"

                delegate: PickerRow {
                    id: rowItem
                    picker: root
                    width: list.width
                    hMargin: root.s(12)
                    icon: rowItem.isHeader ? "" : rowItem.modelData.key
                    iconWidth: root.s(220)
                    iconSize: root.s(13)
                    iconColor: Theme.mauve
                    label: rowItem.isHeader ? "" : rowItem.modelData.action
                    labelSize: root.s(13)
                }
            }
        }
    }
}
