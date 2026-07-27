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

    // Single decode size shared by every WallpaperView across all outputs.
    // Because it is byte-identical everywhere, QQuickPixmapCache keys all
    // monitors' Image elements to ONE decoded buffer (see WallpaperView.qml).
    // Global max WxH so no output has to upscale (PreserveAspectCrop covers).
    readonly property size decodeSize: {
        var w = 0, h = 0, s = Quickshell.screens;
        for (var i = 0; i < s.length; i++) {
            if (s[i].width > w)  w = s[i].width;
            if (s[i].height > h) h = s[i].height;
        }
        return Qt.size(w || 1920, h || 1080);
    }

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
