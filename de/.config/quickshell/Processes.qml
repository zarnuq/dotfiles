pragma ComponentBehavior: Bound
import Quickshell.Io
import QtQuick

// Process killer (Super+X / `qs ipc call processes toggle`; replaces killfzf).
// `ps --forest` snapshot, type to filter, Tab marks, Enter sends SIGTERM to the
// marked rows (or the current one), Ctrl+K sends SIGKILL.
//
// Listed once per open and again after each kill, never polled: a list that
// reshuffled under the cursor would make Enter hit whatever slid into place.
Picker {
    id: root

    ipcTarget: "processes"
    widthFraction: 0.6
    heightFraction: 0.6
    rowHeight: s(30)

    readonly property int queryHeight: s(46)
    readonly property int footerHeight: s(28)

    property var procs: []        // [{pid, user, cpu, mem, args}]
    property string query: ""
    property var marked: ({})     // pid -> true
    property string status: ""

    readonly property var results: {
        var q = root.query.toLowerCase();
        return q === "" ? root.procs
             : root.procs.filter(p => (p.pid + " " + p.user + " " + p.args).toLowerCase().includes(q));
    }
    onQueryChanged: root.selected = 0
    count: root.results.length

    onOpened: { root.marked = ({}); root.status = ""; lister.running = true; }

    Process {
        id: lister
        command: ["ps", "-e", "--forest", "-o", "pid=,ppid=,user=,pcpu=,pmem=,args="]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    // Kernel threads (kthreadd, pid 2, and its children) can't be killed and
    // only bury the list.
    function parse(text): void {
        var out = [];
        text.split("\n").forEach(l => {
            var m = l.match(/^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+) (.*)$/);
            if (!m || m[1] === "2" || m[2] === "2") return;
            out.push({ pid: m[1], user: m[3], cpu: m[4], mem: m[5], args: m[6] });
        });
        root.procs = out;
        if (root.selected >= root.results.length) root.selected = Math.max(0, root.results.length - 1);
    }

    function toggleMark(): void {
        var p = root.results[root.selected];
        if (!p) return;
        var m = root.marked;
        if (m[p.pid]) delete m[p.pid]; else m[p.pid] = true;
        root.marked = m;
        root.move(1);
    }

    function kill(sig): void {
        var pids = Object.keys(root.marked);
        if (!pids.length && root.results[root.selected]) pids = [root.results[root.selected].pid];
        if (!pids.length || killer.running) return;
        killer.command = ["kill", "-" + sig].concat(pids);
        killer.note = "SIG" + sig + " → " + pids.join(" ");
        killer.running = true;
    }

    Process {
        id: killer
        property string note: ""
        stderr: StdioCollector { id: killErr }
        onExited: code => {
            root.status = code === 0 ? killer.note : (killErr.text.trim().split("\n").pop() || "kill failed");
            root.marked = ({});
            relist.restart();
        }
    }
    // SIGTERM is a request; give the process a moment to actually exit.
    Timer { id: relist; interval: 300; onTriggered: lister.running = true }

    box: Component {
        Column {
            spacing: 0

            function reset(): void { search.reset(); root.query = ""; }

            PickerSearch {
                id: search
                picker: root
                width: parent.width
                height: root.queryHeight
                margin: root.s(12)
                fontSize: root.s(19)
                placeholder: "Kill…"
                onTextChanged: root.query = text

                onSubmitted: root.kill("TERM")
                onExtraKey: function (e) {
                    if (e.key === Qt.Key_Tab) root.toggleMark();
                    else if (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier)) root.kill("KILL");
                    else return;
                    e.accepted = true;
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface1 }

            PickerResults {
                id: list
                picker: root
                width: parent.width
                height: parent.height - root.queryHeight - root.footerHeight - 2
                model: root.results
                emptyText: root.procs.length === 0 ? "listing…" : "no matches"
                emptySize: root.s(14)

                delegate: PickerRow {
                    id: rowItem
                    picker: root
                    width: list.width
                    current: !!root.marked[rowItem.modelData.pid]
                    onActivated: root.kill("TERM")

                    hMargin: root.s(12)
                    icon: rowItem.modelData.pid
                    iconWidth: root.s(64)
                    iconSize: root.s(13)
                    iconColor: rowItem.current ? Theme.mauve : Theme.subtext0
                    label: rowItem.modelData.args
                    labelSize: root.s(14)
                    labelColor: rowItem.current ? Theme.mauve : rowItem.sel ? Theme.rowSelectFg : Theme.text
                    trailing: rowItem.modelData.user + "  " + rowItem.modelData.cpu + "%  " + rowItem.modelData.mem + "%"
                    trailingWidth: root.s(170)
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface1 }

            Item {
                width: parent.width
                height: root.footerHeight

                Txt {
                    anchors.left: parent.left
                    anchors.leftMargin: root.s(12)
                    anchors.right: hint.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.status !== "" ? root.status
                          : root.results.length ? (root.selected + 1) + "/" + root.results.length : "0/0"
                    color: root.status !== "" ? Theme.peach : Theme.surface1
                    elide: Text.ElideRight
                    font.pixelSize: root.s(11)
                }

                Txt {
                    id: hint
                    anchors.right: parent.right
                    anchors.rightMargin: root.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⏎ TERM   ^k KILL   tab mark"
                    color: Theme.surface1
                    font.pixelSize: root.s(11)
                }
            }
        }
    }
}
