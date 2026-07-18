pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Wallpaper state + external control (replaces awww).
// Rendered per-screen by WallpaperView. Switched via native IPC:
//   qs ipc call wallpaper random        (Super+b)
//   qs ipc call wallpaper set <path>
Singleton {
    id: root
    property string current: ""
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/bgs"

    // Pick a random image from ~/Pictures/bgs (same set awww's Super+b used).
    Process {
        id: pick
        command: ["sh", "-c",
            "find '" + root.dir + "' -type f \\( -iname '*.jpg' -o -iname '*.png' \\) | shuf -n1"]
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") root.current = text.trim() }
    }

    function random() { pick.running = true; }
    function set(path) { root.current = path; }

    IpcHandler {
        target: "wallpaper"
        function random(): void { root.random(); }
        function set(path: string): void { root.set(path); }
    }

    Component.onCompleted: random()   // never start blank
}
