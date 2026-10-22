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
//
// cliphist keeps no timestamps, so each store appends `<id> <epoch>` to
// `timesPath` for the picker. The id is read back as the top of the list, and
// only logged if it changed: cliphist exits 0 without storing (whitespace-only,
// CLIPBOARD_STATE=sensitive), and the top entry must not be re-stamped then.
// A re-copy gets a fresh id from cliphist, so the newest line per id wins.
// ponytail: the log only grows (~15 bytes a copy); prune against
// `cliphist list` if it ever matters.
Scope {
    id: root

    readonly property string timesPath: Config.stateDir + "/clip-times"

    Variants {
        model: ["text", "image"]

        Process {
            id: watcher
            required property string modelData
            running: true
            command: ["wl-paste", "--type", watcher.modelData, "--watch", "sh", "-c",
                'top() { cliphist list | head -n1 | cut -f1; }; old=$(top); cliphist store || exit; '
                + 'new=$(top); [ -n "$new" ] && [ "$new" != "$old" ] && echo "$new $(date +%s)" >> "$1"',
                "sh", root.timesPath]
            onExited: running = true
        }
    }
}
