pragma ComponentBehavior: Bound
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
// The picker half is `ClipboardPicker.qml` (Super+V), which reads
// `cliphist list` itself. The old `clipfzf` script is gone.
Scope {
    id: root
    Variants {
        model: ["text", "image"]

        Process {
            required property string modelData
            running: true
            command: ["wl-paste", "--type", modelData, "--watch", "cliphist", "store"]
            onExited: running = true
        }
    }
}
