pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Shared power-mode state: the current mode, applying one, and the OSD hook.
// Both the PowerMode menu and (future) a cycle keybind go through here so the
// OSD has one place to watch. ~/.local/bin/powermode does the sysfs writes
// (user-level via the 99-powermode.rules udev rule); this only drives it.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/powermode"
    property string mode: ""
    signal flashed(string mode)   // Osd listens to this

    readonly property var order: ["performance", "balanced", "saver"]
    function iconFor(m) { return ({ performance: "󰓅", balanced: "󰾅", saver: "󰌪" })[m] || "󰾅"; }
    function labelFor(m) { return ({ performance: "Performance", balanced: "Balanced", saver: "Power saver" })[m] || m; }

    Process {
        id: getter
        command: [root.script, "get"]
        stdout: StdioCollector { id: got }
        onExited: root.mode = got.text.trim()
    }
    Process { id: setter; stderr: StdioCollector {} }

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

    function cycle(): void {
        var i = root.order.indexOf(root.mode);
        root.apply(root.order[(i + 1) % root.order.length]);
    }

    Connections {
        target: setter
        function onExited(): void { root.refresh(); }
    }

    // Keybind / debug entry point. Separate target from the "powermode" menu so
    // the two IpcHandlers don't collide.
    IpcHandler {
        target: "power"
        function set(mode: string): void { root.apply(mode); }
        function cycle(): void { root.cycle(); }
        function get(): string { return root.mode; }
    }

    Component.onCompleted: root.refresh()
}
