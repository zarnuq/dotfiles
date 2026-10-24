pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import "Ansi.js" as Ansi

// tmux sessions as a tree, like prefix+s (Super+Shift+Tab / `qs ipc call tmux
// toggle`): session → window → pane, l/h expand and collapse, the selected
// row's pane previewed on the right. Enter switches the most recently active
// tmux client to that pane, or attaches a new kitty when none is attached —
// reach can't be asked to raise a window, so a client on a hidden desktop
// switches out of sight. `x` kills the row's object. Everything is addressed
// by tmux's ids ($s @w %p), so names never get quoted.
Picker {
    id: root

    ipcTarget: "tmux"

    property var panes: []
    property string lastText: ""
    property var collapsed: ({})    // id → true; everything starts expanded

    Poll {
        id: ls
        running: root.open
        interval: 2000
        command: ["tmux", "list-panes", "-a", "-F",
                  "#{session_id}\t#{session_name}\t#{session_attached}\t#{window_id}\t#{window_index}\t#{window_name}\t#{window_active}\t#{pane_id}\t#{pane_index}\t#{pane_current_command}\t#{pane_active}"]
        // Same text = same tree; reassigning would rebuild every row.
        onData: text => {
            if (text === root.lastText) return;
            root.lastText = text;
            root.panes = text.split("\n").filter(l => l).map(l => l.split("\t"));
        }
    }

    onOpenChanged: if (open) root.collapsed = {}

    rows: {
        var r = [];
        var sessions = [];
        var bySession = {};
        root.panes.forEach(f => {
            var s = bySession[f[0]];
            if (!s) {
                s = bySession[f[0]] = { id: f[0], name: f[1], attached: f[2] !== "0", windows: [], byWin: {} };
                sessions.push(s);
            }
            var w = s.byWin[f[3]];
            if (!w) {
                w = s.byWin[f[3]] = { id: f[3], index: f[4], name: f[5], active: f[6] === "1", panes: [] };
                s.windows.push(w);
            }
            w.panes.push({ id: f[7], index: f[8], cmd: f[9], active: f[10] === "1" });
        });

        // Each row previews (and Enter lands on) a pane: its own, else the one
        // that's current in its window / session.
        var activePane = w => (w.panes.find(p => p.active) || w.panes[0]).id;

        sessions.forEach(s => {
            var sOpen = !root.collapsed[s.id];
            r.push({ kind: "session", id: s.id, session: s.id, label: s.name, attached: s.attached,
                     pane: activePane(s.windows.find(w => w.active) || s.windows[0]), depth: 0, open: sOpen, hasKids: sOpen, trailing: s.windows.length + (s.windows.length === 1 ? " window" : " windows") });
            if (!sOpen) return;
            s.windows.forEach((w, wi) => {
                var wLast = wi === s.windows.length - 1;
                var multi = w.panes.length > 1;
                var wOpen = multi && !root.collapsed[w.id];
                r.push({ kind: "window", id: w.id, session: s.id, parent: s.id, open: wOpen, multi: multi,
                         pane: activePane(w), depth: 1, last: wLast, hasKids: wOpen,
                         label: w.index + ": " + w.name + (w.active ? " *" : ""),
                         trailing: multi ? w.panes.length + " panes" : w.panes[0].cmd });
                if (!wOpen) return;
                w.panes.forEach((p, pi) => {
                    r.push({ kind: "pane", id: p.id, session: s.id, window: w.id, parent: w.id,
                             pane: p.id, depth: 2, last: pi === w.panes.length - 1, parentLast: wLast,
                             label: p.index + ": " + p.cmd + (p.active ? " *" : ""),
                             trailing: p.id });
                });
            });
        });
        r.push({ kind: "new" });
        return r;
    }

    rowHeight: s(32)
    barHeight: s(30)
    minBoxHeight: s(380)
    readonly property int listWidth: s(520)
    boxWidth: listWidth + s(640)

    // The selected row's pane, re-captured on selection and every second. Its
    // own Process rather than a Poll: the pane captured is pinned at launch,
    // so a capture still running when the selection moves can't paint the
    // old pane's screen into the new row, and nothing is blanked or rewritten
    // unless the text actually changed.
    readonly property string previewPane: rows[selected] && rows[selected].pane || ""
    property string previewText: ""
    readonly property var preview: Ansi.toHtml(root.previewText, Theme.font)
    onPreviewPaneChanged: settle.restart()

    Timer {
        id: settle                       // holding j mustn't fork a capture per row
        interval: 60
        onTriggered: root.capture()
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.open && root.previewPane !== ""
        onTriggered: root.capture()
    }

    function capture(): void {
        if (cap.running || !root.previewPane) return;
        cap.pane = root.previewPane;
        cap.command = ["tmux", "capture-pane", "-p", "-e", "-t", cap.pane];
        cap.running = true;
    }
    Process {
        id: cap
        property string pane: ""
        // Selection moved while this ran: capture the new pane now.
        onRunningChanged: if (!running && pane !== root.previewPane) root.capture()
        stdout: StdioCollector {
            onStreamFinished: {
                if (cap.pane !== root.previewPane) return;
                var t = text.replace(/\s+$/, "");
                if (t !== root.previewText) root.previewText = t;
            }
        }
    }

    function setExpanded(id, on): void {
        var c = Object.assign({}, root.collapsed);
        if (on) delete c[id]; else c[id] = true;
        root.collapsed = c;
    }

    // Tree geometry: a depth-d label starts at labelX(d); its children's
    // trunk runs down trunkX(d). Lines are Rectangles, not box-drawing glyphs,
    // which leave a gap between rows taller than the font.
    readonly property int indent: s(22)
    function labelX(d) { return s(54) + d * root.indent; }
    function trunkX(d) { return root.labelX(d) + s(6); }

    // l: open the row. h: close it, or step to the parent and close that.
    function expand(i): void {
        var r = rows[i];
        if (r && (r.kind === "session" || (r.kind === "window" && r.multi))) root.setExpanded(r.id, true);
    }
    function collapse(i): void {
        var r = rows[i];
        if (!r || r.kind === "new") return;
        if (r.open) { root.setExpanded(r.id, false); return; }
        if (!r.parent) return;
        for (var j = i - 1; j >= 0; j--)
            if (rows[j].id === r.parent) { root.selected = j; root.setExpanded(r.parent, false); return; }
    }

    function activate(i): void {
        var r = rows[i];
        if (!r) return;
        if (r.kind === "new") {
            Quickshell.execDetached(["kitty", "-e", "tmux", "new-session", "-c", Quickshell.env("HOME")]);
        } else {
            // switch-client -t <pane> changes session, window and pane at once.
            Quickshell.execDetached(["sh", "-c",
                'c=$(tmux list-clients -F "#{client_activity} #{client_tty}" | sort -rn | head -n1 | cut -d" " -f2); '
                + 'if [ -n "$c" ]; then tmux switch-client -c "$c" -t "$1"; '
                + 'else exec kitty -e tmux select-window -t "$1" \\; select-pane -t "$1" \\; attach -t "$1"; fi',
                "_", r.pane]);
        }
        root.hide();
    }

    function kill(i): void {
        var r = rows[i];
        if (!r || r.kind === "new") return;
        Quickshell.execDetached(["tmux", "kill-" + r.kind, "-t", r.id]);
        ls.refresh();
    }

    box: Component {
        FocusScope {
            PickerList {
                width: root.listWidth
                height: parent.height
                focus: true
                picker: root
                hint: "enter attach · l/h expand · x kill"

                onExtraKey: function (e) {
                    if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return;
                    if (e.key === Qt.Key_L || e.key === Qt.Key_Right) root.expand(root.selected);
                    else if (e.key === Qt.Key_H || e.key === Qt.Key_Left) root.collapse(root.selected);
                    else if (e.key === Qt.Key_X) root.kill(root.selected);
                    else return;
                    e.accepted = true;
                }

                rowDelegate: Item {
                    id: node
                    required property var modelData
                    required property int index
                    readonly property var m: node.modelData
                    readonly property int d: node.m.depth || 0
                    readonly property int line: Math.max(1, root.s(1))

                    width: parent.width
                    height: rowItem.height

                    PickerRow {
                        id: rowItem
                        picker: root
                        modelData: node.modelData
                        index: node.index
                        width: parent.width
                        current: node.m.kind === "session" && node.m.attached
                        onActivated: root.activate(node.index)

                        icon: node.m.kind === "new" ? "󰐕" : node.m.kind === "session" ? (node.m.open ? "▾" : "▸") : " "
                        iconWidth: root.s(24) + node.d * root.indent
                        label: node.m.kind === "new" ? "new session" : node.m.label
                        trailing: node.m.trailing || ""
                        trailingWidth: root.s(110)
                        trailingColor: rowItem.current ? Theme.mauve : Theme.subtext0
                    }

                    // Connector into this row from its parent's trunk.
                    Rectangle {
                        visible: node.d > 0
                        x: root.trunkX(node.d - 1); y: 0
                        width: node.line; height: node.m.last ? node.height / 2 : node.height
                        color: Theme.overlay0
                    }
                    Rectangle {
                        visible: node.d > 0
                        x: root.trunkX(node.d - 1); y: node.height / 2
                        width: root.labelX(node.d) - root.s(6) - x; height: node.line
                        color: Theme.overlay0
                    }
                    // The session trunk passing a pane on its way to later windows.
                    Rectangle {
                        visible: node.d === 2 && !node.m.parentLast
                        x: root.trunkX(0); y: 0
                        width: node.line; height: node.height
                        color: Theme.overlay0
                    }
                    // Stub from under an open row's label down to its first child.
                    Rectangle {
                        visible: !!node.m.hasKids
                        x: root.trunkX(node.d); y: node.height / 2 + root.s(9)
                        width: node.line; height: node.height - y
                        color: Theme.overlay0
                    }
                }
            }

            Rectangle {
                x: root.listWidth
                width: 1
                height: parent.height
                color: Theme.surface1
            }

            // The capture, in colour, shrunk to fit: a pane is usually far
            // bigger than this panel. Sized by hand from the content's extent
            // (JetBrains Mono: 0.6em advance, ~1.3em line) since fontSizeMode
            // doesn't apply to RichText. Below the floor it crops right/bottom.
            Txt {
                x: root.listWidth + 1 + root.s(12)
                y: root.s(12)
                width: parent.width - x - root.s(12)
                height: parent.height - root.s(24)
                clip: true
                textFormat: Text.RichText
                text: root.preview.html
                wrapMode: Text.NoWrap
                font.pixelSize: Math.max(root.s(6), Math.min(root.s(11),
                    Math.floor(width / (Math.max(1, root.preview.cols) * 0.6)),
                    Math.floor(height / (Math.max(1, root.preview.rows) * 1.3))))
            }
        }
    }
}
