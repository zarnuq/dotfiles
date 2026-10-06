pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Removable drives (Super+R u / `qs ipc call drives toggle`): every hotplug
// disk's filesystems, mounted or not. Enter mounts (udisksctl, under
// /run/media/$USER) or, once mounted, opens it in yazi; `u` unmounts, `e`
// unmounts everything on that disk and powers it off so it can be pulled.
//
// Mounting needs polkit to say yes, and with no logind/elogind there is no
// "active session" for udisks' allow_active — so without a rules.d entry
// granting plugdev the mount actions, udisksctl fails "Not authorized" (shown
// in the status line). `--no-user-interaction` keeps it from waiting on an
// agent that isn't there.
Picker {
    id: root

    ipcTarget: "drives"

    property var disks: []
    property string status: ""

    Poll {
        id: blk
        running: root.open
        interval: 3000
        command: ["lsblk", "-J", "-o", "PATH,LABEL,SIZE,FSTYPE,MOUNTPOINT,HOTPLUG,TYPE,MODEL"]
        onJsonData: v => root.disks = v ? v.blockdevices.filter(d => d.hotplug && d.type === "disk") : []
    }

    // A header per disk, then each filesystem on it — partitions, or the bare
    // disk when it has no partition table.
    rows: {
        var r = [];
        root.disks.forEach(d => {
            var parts = (d.children || []).filter(p => p.fstype);
            if (d.fstype) parts.unshift(d);
            if (!parts.length) return;
            r.push({ kind: "header", label: ((d.model || "").trim() || d.path) + " · " + d.size });
            parts.forEach(p => r.push({ kind: "fs", fs: p, disk: d }));
        });
        return r.length ? r : [{ kind: "none" }];
    }

    rowHeight: s(36)
    barHeight: s(30)
    minBoxHeight: s(140)
    boxWidth: s(480)

    Process {
        id: act
        stdout: StdioCollector { id: actOut }
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            root.status = code === 0 ? actOut.text.trim().split("\n").pop() || ""
                        : actErr.text.trim().split("\n").pop() || "failed (exit " + code + ")";
            blk.refresh();
        }
    }

    function run(cmd, note): void {
        if (act.running) return;
        root.status = note;
        act.command = cmd;
        act.running = true;
    }

    function activate(i): void {
        if (!selectable(i) || rows[i].kind !== "fs") return;
        var fs = rows[i].fs;
        if (fs.mountpoint) {
            // Same yazi launch as the launcher's file mode: `q` leaves a shell
            // in the directory yazi was left in.
            Quickshell.execDetached(["kitty", "-e", "zsh", "-ic", "y \"$1\"; exec zsh", "_", fs.mountpoint]);
            root.hide();
        } else {
            root.run(["udisksctl", "mount", "--no-user-interaction", "-b", fs.path], "mounting " + fs.path + "…");
        }
    }

    function unmount(i): void {
        if (!selectable(i) || rows[i].kind !== "fs" || !rows[i].fs.mountpoint) return;
        root.run(["udisksctl", "unmount", "--no-user-interaction", "-b", rows[i].fs.path], "unmounting…");
    }

    function eject(i): void {
        if (!selectable(i) || rows[i].kind !== "fs") return;
        var d = rows[i].disk;
        var mounted = [d].concat(d.children || []).filter(p => p.mountpoint).map(p => p.path);
        root.run(["sh", "-c", "for p in \"$@\"; do udisksctl unmount --no-user-interaction -b \"$p\" || exit; done; "
                  + "udisksctl power-off --no-user-interaction -b \"$0\" && echo \"$0 can be removed\"",
                  d.path].concat(mounted), "ejecting " + d.path + "…");
    }

    onOpenChanged: if (!open) root.status = ""

    box: Component {
        PickerList {
            picker: root
            status: root.status
            hint: "enter mount / open · u unmount · e eject"

            onExtraKey: function (e) {
                if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return;
                if (e.key === Qt.Key_U) root.unmount(root.selected);
                else if (e.key === Qt.Key_E) root.eject(root.selected);
                else return;
                e.accepted = true;
            }

            rowDelegate: PickerRow {
                id: rowItem
                readonly property var fs: rowItem.isHeader ? null : rowItem.modelData.fs || null

                picker: root
                width: parent.width
                current: !!(rowItem.fs && rowItem.fs.mountpoint)
                onActivated: root.activate(rowItem.index)

                icon: rowItem.isHeader ? "" : rowItem.fs ? "󰋊" : "󰕓"
                label: rowItem.isHeader ? ""
                       : rowItem.fs ? (rowItem.fs.label || rowItem.fs.path) + "  " + rowItem.fs.fstype + " · " + rowItem.fs.size
                       : "no removable drives"
                trailing: rowItem.current ? rowItem.fs.mountpoint.split("/").pop() : ""
                trailingWidth: root.s(110)
                trailingColor: Theme.mauve
            }

        }
    }
}
