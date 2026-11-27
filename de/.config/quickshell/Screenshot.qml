pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Screenshots, plus the capture menu (`qs ipc call screenshots toggle`,
// Super+S a) that also starts and stops Recorder's screen recordings. The
// `capture` IPC target is what the rest of the Super+S chord calls:
//
//   qs ipc call capture region         slurp a region
//   qs ipc call capture display <n>    whole display n, 1-based left to right
//   qs ipc call capture output <name>  whole output by name
//   qs ipc call capture annotate       clipboard image → Annotate.qml
//
// Every capture goes to the clipboard, never a file; `annotate` pulls the
// image back off into the annotator, whose Ctrl+S is the only thing that
// writes to ~/Pictures. Switching "Screenshots" off in settings takes the chord with it.
Scope {
    id: root

    /// POSIX single-quoting, since an output name reaches a shell.
    function sq(v) { return "'" + String(v).replace(/'/g, "'\\''") + "'"; }

    // `grab` writes the PNG to stdout. It goes through a file, not a pipe, so
    // a failed grim stops at the `&&` instead of announcing "Copied!". A
    // capture over 5 MB (a busy ultrawide) is shrunk to at most 2560x1080's
    // area, any shape, since cliphist 0.7.0 silently drops anything bigger and
    // it would never reach the clipboard history. A cancelled slurp exits
    // before grim, so a cancel stays silent. execDetached because wl-copy
    // forks a daemon to serve the selection, and that has to outlive the call.
    // zq: one shrink, no retry; a pathologically noisy capture can still top
    // 5 MB at that size. Loop on smaller areas if that ever happens.
    function copy(grab): void {
        Quickshell.execDetached(["bash", "-c",
            grab + " > \"$1\" && if [ $(stat -c %s \"$1\") -gt 5000000 ]; then"
            + " magick png:\"$1\" -resize '2764800@>' png:\"$1.tmp\" && mv \"$1.tmp\" \"$1\"; fi"
            + " && wl-copy --type image/png < \"$1\" && notify-send Screenshot 'Copied!'",
            "_", Config.runtimeDir + "/shot"]);
    }

    IpcHandler {
        id: ipc
        target: "capture"

        function region(): void {
            root.copy("g=$(slurp) || exit 1; grim -g \"$g\" -");
        }

        // Config.displays' numbering — the one the Displays window's Identify
        // shows. A number past the heads this machine has does nothing.
        function display(n: int): void {
            if (n >= 1 && n <= Config.displays.length) ipc.output(Config.displays[n - 1].name);
        }

        // Any output grim knows — it rejects a name it does not, and says which.
        // The sleep lets the capture menu's overlay unmap first when it called.
        function output(name: string): void {
            root.copy("sleep 0.2; grim -o " + root.sq(name) + " -");
        }

        // Into the annotator window (Annotate.qml), which writes ~/Pictures
        // only on Ctrl+S.
        function annotate(): void { dump.running = true; }
    }

    // The clipboard image onto disk, for the annotator to load. First image
    // type on offer, since not every source advertises png.
    property string editing: ""
    Process {
        id: dump
        readonly property string file: Config.runtimeDir + "/annotate.png"
        command: ["bash", "-c", "t=$(wl-paste --list-types 2>/dev/null | grep -m1 '^image/')"
                  + " || { notify-send Screenshot 'No image on the clipboard'; exit 1; }; "
                  + "wl-paste --no-newline --type \"$t\" > \"$1\"", "_", file]
        onExited: code => { if (code === 0) root.editing = dump.file; }
    }
    LazyLoader {
        active: root.editing !== ""
        Annotate { path: root.editing; onDone: root.editing = "" }
    }

    Picker {
        id: menu
        ipcTarget: "screenshots"

        rows: {
            var shots = [{ kind: "header", label: "Screenshot" },
                         { kind: "shot", label: "Region", icon: "󰩭" }];
            var recs = [{ kind: "header", label: "Record" },
                        { kind: "sound", label: "Desktop sound" },
                        { kind: "mic", label: "Microphone" },
                        { kind: "rec", label: "Region", icon: "󰩭" }];
            for (var i = 0; i < Config.displays.length; i++) {
                var d = { label: "Display " + (i + 1), icon: "󰍹", output: Config.displays[i].name };
                shots.push(Object.assign({ kind: "shot" }, d));
                recs.push(Object.assign({ kind: "rec" }, d));
            }
            shots.push({ kind: "annotate", label: "Annotate clipboard", icon: "󰏬" });
            // One recording at a time: while one runs, Stop takes the place
            // of the Record section, first so the menu opens on it.
            if (Recorder.recording)
                return [{ kind: "header", label: "Recording" },
                        { kind: "stop", label: "Stop Recording", icon: "󰓛" }].concat(shots);
            return shots.concat(recs);
        }

        boxWidth: s(420)

        function activate(i): void {
            if (!selectable(i)) return;
            var r = rows[i];
            if (r.kind === "sound" || r.kind === "mic") { Recorder[r.kind] = !Recorder[r.kind]; return; }
            menu.hide();
            if (r.kind === "stop") Recorder.stop();
            else if (r.kind === "annotate") ipc.annotate();
            else if (r.kind === "shot") r.output ? ipc.output(r.output) : ipc.region();
            else r.output ? Recorder.output(r.output) : Recorder.region();
        }

        box: Component {
            PickerList {
                picker: menu
                rowDelegate: PickerRow {
                    id: rowItem
                    picker: menu
                    width: parent.width
                    onActivated: menu.activate(rowItem.index)
                    readonly property bool box_: rowItem.modelData.kind === "sound" || rowItem.modelData.kind === "mic"
                    readonly property bool ticked: rowItem.box_ && Recorder[rowItem.modelData.kind]
                    icon: rowItem.isHeader ? "" : rowItem.box_ ? (rowItem.ticked ? "󰄲" : "󰄱") : rowItem.modelData.icon
                    iconColor: rowItem.modelData.kind === "stop" ? Theme.red
                             : rowItem.ticked ? Theme.mauve
                             : rowItem.sel ? Theme.mauve : Theme.subtext0
                    label: rowItem.isHeader ? "" : rowItem.modelData.label
                    trailing: rowItem.modelData.output || ""
                    trailingWidth: menu.s(90)
                }
            }
        }
    }
}
