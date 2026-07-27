import Quickshell
import Quickshell.Io

// Clipboard-history capture (replaces the runit `cliphist` group service).
//
// wl-paste can only --watch one MIME type per process, so history needs two
// watchers (text + image), exactly as the old service ran them. Spawned as
// quickshell child processes they inherit qs's live WAYLAND_DISPLAY (no socket
// wait needed) and are torn down with qs. Each restarts itself if it exits,
// mirroring runsv's supervision of the old group service.
//
// Picker unchanged: `clipfzf` (Super+V) still reads `cliphist list`.
Scope {
    Process {
        id: textWatch
        running: true
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
        onExited: running = true
    }
    Process {
        id: imageWatch
        running: true
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
        onExited: running = true
    }
}
