pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Wallpaper state + external control (replaces awww).
// Rendered per-screen by WallpaperView (static) or mpvpaper (video).
// Switched via native IPC:
//   qs ipc call wallpaper random        (Super+b)
//   qs ipc call wallpaper set <path>
Singleton {
    id: root
    property string current: ""
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/bgs"
    property bool isVideo: false

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

    Process {
        id: pick
        command: ["sh", "-c",
            "find '" + root.dir + "' -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.mp4' \\) | shuf -n1"]
        stdout: StdioCollector { onStreamFinished: root.current = text.trim() || root.current }
    }

    // mpvpaper manages its own layer-shell background surfaces.
    // ponytail: demuxer-max-bytes=512KiB (default 150MB) — 2MB loop file needs nothing more
    function startVideo(): void {
        stopVideo();
        Quickshell.execDetached(["sh", "-c",
            "mpvpaper -o 'no-audio loop-file=inf hwdec=auto panscan=1.0 no-cache demuxer-max-bytes=512KiB demuxer-max-back-bytes=0' ALL '"
            + root.current + "' >/dev/null 2>&1"]);
    }

    Process {
        id: killVideo
        command: ["pkill", "-x", "mpvpaper"]
    }
    function stopVideo(): void { killVideo.running = true; }

    onCurrentChanged: {
        if (!root.current) return;
        root.isVideo = root.current.toLowerCase().endsWith(".mp4");
        if (root.isVideo) {
            startVideo();
        } else {
            stopVideo();
            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/theme-set", "--wallpaper", root.current]);
        }
    }

    function random(): void { pick.running = true; }
    function set(path): void {
        if (root.current === path) root.currentChanged();
        else root.current = path;
    }

    IpcHandler {
        target: "wallpaper"
        function random(): void { root.random(); }
        function set(path: string): void { root.set(path); }
    }

    Component.onCompleted: random()   // never start blank
}
