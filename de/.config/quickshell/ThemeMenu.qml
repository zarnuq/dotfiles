pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Palette menu (Super+R c / `qs ipc call theme toggle`): pin a fixed palette
// (one row per ~/.config/theme/<id>.json) or follow the wallpaper. A front end for ~/.local/bin/theme-set, which owns the
// palette, the mode file and every app's render — see **Palette switching** in
// the root CLAUDE.md. The current mode is read back from theme-set's own mode
// file rather than remembered here, so a switch from a terminal shows up too.
Picker {
    id: root

    ipcTarget: "theme"

    rows: [
        { kind: "mode", id: "mocha",   icon: "󰄛", label: "Catppuccin Mocha", desc: "fixed" },
        { kind: "mode", id: "gruvbox", icon: "󰄛", label: "Gruvbox",          desc: "fixed" },
        { kind: "mode", id: "auto",  icon: "󰸉", label: "Follow wallpaper", desc: "matugen" }
    ]
    boxWidth: s(380)
    barHeight: s(30)

    // theme-set's default when it has never been told is mocha, so a missing
    // file means the same here.
    property string mode: "mocha"
    FileView {
        id: modeFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/theme/mode"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.mode = text().trim() || "mocha"
    }

    property string status: ""
    onOpenChanged: if (open) root.status = ""

    // Kept open on failure so the reason is readable: theme-set exits non-zero
    // with one line when matugen can't read the wallpaper, or none is recorded.
    Process {
        id: apply
        stderr: StdioCollector { id: applyErr }
        onExited: code => {
            if (code === 0) root.hide();
            else root.status = applyErr.text.trim().split("\n").pop() || ("theme-set exited " + code);
        }
    }

    function activate(i): void {
        if (!selectable(i) || apply.running) return;
        root.status = "applying…";
        apply.command = [Quickshell.env("HOME") + "/.local/bin/theme-set", rows[i].id];
        apply.running = true;
    }

    box: Component {
        PickerList {
            picker: root
            hint: "enter apply"
            status: root.status

            rowDelegate: PickerRow {
                id: rowItem
                picker: root
                width: parent.width
                current: rowItem.modelData.id === root.mode
                onActivated: root.activate(rowItem.index)

                icon: rowItem.modelData.icon
                label: rowItem.modelData.label
                trailing: rowItem.modelData.desc
                trailingWidth: root.s(90)
                trailingColor: Theme.overlay0
            }
        }
    }
}
