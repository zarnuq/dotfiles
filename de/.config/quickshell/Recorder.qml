pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Screen recording with wf-recorder, started from the capture menu
// (Screenshot.qml) and shown on the bar while it runs. A singleton because the
// bar has to see it and the recording outlives the menu that started it.
//
// Lands in ~/Pictures next to the annotator's screenshots.
Singleton {
    id: root

    readonly property bool recording: proc.running
    property string file: ""
    // Ticked in the menu; both off records no audio.
    property bool sound: false   // desktop audio, the default sink's monitor
    property bool mic: false     // the default source

    // Exit code for a cancelled slurp, so a cancel stays silent like the
    // screenshot path while a real failure is still reported.
    readonly property int cancelled: 3

    // slurp reads preset boxes from a non-tty stdin, and Process's stdin is a
    // pipe that never closes: without </dev/null it blocks before drawing.
    function region(): void {
        root.start("g=$(slurp </dev/null) || exit " + root.cancelled + "; set -- \"$@\" -g \"$g\"; ", []);
    }

    // The menu's overlay is still mapped for a moment after hide(), so a
    // whole-output recording waits for it to leave the frame.
    function output(name): void {
        root.start("sleep 0.2; ", ["-o", name]);
    }

    // wf-recorder takes one audio device, so desktop + mic are mixed into a
    // throwaway null sink and its monitor is recorded. The modules are found
    // by name and dropped on exit, and before loading, in case a killed shell
    // left some behind.
    readonly property string mix:
        "drop() { pactl list short modules | awk '/qs_rec/ {print $1}' | xargs -r -n1 pactl unload-module; }; "
        + "drop; trap drop EXIT; "
        + "pactl load-module module-null-sink sink_name=qs_rec sink_properties=device.description=Recording-mix >/dev/null || exit 1; "
        + "pactl load-module module-loopback source=@DEFAULT_MONITOR@ sink=qs_rec >/dev/null; "
        + "pactl load-module module-loopback source=@DEFAULT_SOURCE@ sink=qs_rec >/dev/null; "

    // Not exec'd, so the EXIT trap above can run. stop() sends SIGTERM, not
    // SIGINT: a shell started with SIGINT ignored can't trap it. wf-recorder
    // finalises on either, and can take seconds to drain its encoder.
    readonly property string body:
        "wf-recorder -y -f \"$1\" \"${@:2}\" & p=$!; trap \"kill -TERM $p\" INT TERM; "
        + "while kill -0 $p 2>/dev/null; do wait $p; r=$?; done; exit $r"

    function start(prefix, args): void {
        if (proc.running) return;
        root.file = Quickshell.env("HOME") + "/Pictures/recording-"
                    + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        var both = root.sound && root.mic;
        var dev = both ? "qs_rec.monitor" : root.sound ? "@DEFAULT_MONITOR@" : root.mic ? "@DEFAULT_SOURCE@" : "";
        proc.command = ["bash", "-c", (both ? root.mix : "") + prefix + root.body, "_", root.file]
                       .concat(args, dev ? ["--audio=" + dev] : []);
        proc.running = true;
    }

    function stop(): void { if (proc.running) proc.signal(15); }

    Process {
        id: proc
        stderr: StdioCollector { id: err }
        onExited: code => {
            if (code === 0)
                Quickshell.execDetached(["notify-send", "Recording", "Saved " + root.file]);
            else if (code !== root.cancelled)
                Quickshell.execDetached(["notify-send", "-u", "critical", "Recording failed",
                                         err.text.trim().split("\n").pop() || ("exit " + code)]);
        }
    }
}
