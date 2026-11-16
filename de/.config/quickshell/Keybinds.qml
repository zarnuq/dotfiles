pragma ComponentBehavior: Bound
import Quickshell
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

    readonly property int queryHeight: s(46)

    readonly property string configPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/reach/config.zon"

    property var all: []
    property string query: ""
    readonly property var results: Keybinds.filter(root.all, root.query)
    onQueryChanged: root.selected = 0
    count: root.results.length

    FileView { id: cfg; path: root.configPath; blockLoading: true; printErrors: false }

    onOpened: { cfg.reload(); root.all = Keybinds.parse(cfg.text()); }

    box: Component {
        Column {
            spacing: 0

            function reset(): void { search.reset(); root.query = ""; }

            PickerSearch {
                id: search
                picker: root
                width: parent.width
                height: root.queryHeight
                margin: root.s(12)
                fontSize: root.s(19)
                placeholder: "Keybinds…"
                onTextChanged: root.query = text
                onSubmitted: root.hide()
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface1 }

            PickerResults {
                id: list
                picker: root
                width: parent.width
                height: parent.height - root.queryHeight - footer.height - 1
                model: root.results
                emptyText: root.all.length === 0 ? "no .binds in " + root.configPath : "no matches"
                emptySize: root.s(14)

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

            PickerFooter {
                id: footer
                picker: root
                hint: "from reach/config.zon   esc close"
            }
        }
    }
}
