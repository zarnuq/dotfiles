pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Shared power-mode state: the current mode, applying one, and the OSD hook.
// The PowerMode menu goes through here so the OSD has one place to watch.
// ~/.local/bin/powermode does the sysfs writes (user-level via the
// 99-powermode.rules udev rule); this only drives it.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/powermode"
    property string mode: ""
    signal flashed(string mode)   // Osd listens to this

    readonly property var modes: [
        { id: "performance", icon: "󰓅", label: "Performance", desc: "max clocks, boost" },
        { id: "balanced",    icon: "󰾅", label: "Balanced",    desc: "default" },
        { id: "saver",       icon: "󰌪", label: "Power saver", desc: "2 GHz cap, no boost" }
    ]
    function info(m) { return root.modes.find(x => x.id === m) || { icon: "󰾅", label: m }; }

    Process {
        id: getter
        command: [root.script, "get"]
        stdout: StdioCollector { id: got }
        onExited: root.mode = got.text.trim()
    }
    Process {
        id: setter
        onExited: root.refresh()
    }

    function refresh(): void { getter.running = true; }

    /// Switch mode. The sysfs write is ~15ms but the menu felt slow because it
    /// waited on a re-read; set `mode` optimistically and flash the OSD now, then
    /// run the script and reconcile from disk when it exits.
    function apply(m): void {
        root.mode = m;
        root.flashed(m);
        setter.command = [root.script, "apply", m];
        setter.running = true;
    }

    Component.onCompleted: root.refresh()
}
