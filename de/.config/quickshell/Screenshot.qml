pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Screenshots. No surface — just the `capture` IPC target the Super+S chord
// calls:
//
//   qs ipc call capture region         slurp a region
//   qs ipc call capture display <n>    whole display n, 1-based left to right
//   qs ipc call capture output <name>  whole output by name
//   qs ipc call capture annotate       clipboard image → satty
//
// Every capture goes to the clipboard, never a file; `annotate` pulls the
// image back off into satty, whose save is the only thing that writes to
// ~/Pictures. Switching "Screenshots" off in settings takes the chord with it.
Scope {
    id: root

    IpcHandler {
        target: "capture"
        function region(): void { root.region(); }
        function display(n: int): void { root.display(n); }
        function output(name: string): void { root.output(name); }
        function annotate(): void { root.annotate(); }
    }

    /// POSIX single-quoting, since an output name reaches a shell.
    function sq(v) { return "'" + String(v).replace(/'/g, "'\\''") + "'"; }

    // bash, not sh, for pipefail: a pipeline otherwise reports its LAST
    // command, so `grim … | wl-copy` returned wl-copy's status and the `&&`
    // tested the paste rather than the capture — a failed grim still announced
    // "Copied!". A cancelled slurp is caught before the pipeline even starts,
    // so a cancel stays silent. execDetached because wl-copy forks a daemon to
    // serve the selection, and that has to outlive the call.
    function run(cmd): void {
        Quickshell.execDetached(["bash", "-c", "set -o pipefail; " + cmd]);
    }
    readonly property string copied: " | wl-copy --type image/png && notify-send Screenshot 'Copied!'"

    function region(): void {
        root.run("g=$(slurp) || exit 1; grim -g \"$g\" -" + root.copied);
    }

    // Config.displays' numbering — the one the Displays window's Identify
    // shows. A number past the heads this machine has does nothing.
    function display(n): void {
        if (n >= 1 && n <= Config.displays.length) root.output(Config.displays[n - 1].name);
    }

    // Any output grim knows — it rejects a name it does not, and says which.
    function output(name): void {
        root.run("grim -o " + root.sq(name) + " -" + root.copied);
    }

    // First image type on offer, since not every source advertises png.
    // --copy-command because satty's own GTK clipboard empties when it exits,
    // so copy-then-close would paste nothing; satty expands the `~` and the
    // strftime fields in the output name itself.
    function annotate(): void {
        root.run("t=$(wl-paste --list-types 2>/dev/null | grep -m1 '^image/')"
                 + " || { notify-send Screenshot 'No image on the clipboard'; exit 1; }; "
                 + "wl-paste --no-newline --type \"$t\" | satty --filename -"
                 + " --output-filename '~/Pictures/screenshot-%Y-%m-%d_%H-%M-%S.png'"
                 + " --copy-command wl-copy");
    }
}
