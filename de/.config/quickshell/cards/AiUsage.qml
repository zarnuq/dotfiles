pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import QtQml.Models
import ".."   // Theme, Config, Txt, Poll and the root singletons

// AI usage, bottom-right above the syncthing card.
//
// Claude and Codex need no network call. Claude Code only exposes its limits on
// the statusline's stdin, so `statusline-command.sh` mirrors them to
// ~/.local/state/ai-usage/claude.json and this card watches that file — the
// numbers move only while some Claude session is drawing a statusline. Codex
// writes `rate_limits` into its session rollouts; one `tac | grep -m1` over the
// newest few each minute reads the last snapshot (same source as
// ai-cli-subagents' delegate.py). A window whose reset time has passed is
// shown as 0 even when the snapshot is older than that.
// agy /quota adds its Gemini and Claude/GPT pools every five minutes without
// model tokens. Kiro's monthly credits come from its client-side /usage slash
// command (no model turn) every fifteen minutes; the script deletes the chat
// session each headless run saves.
Widget {
    id: root
    anchors { bottom: true; right: true }
    margins { bottom: Config.syncthingHeight }
    implicitWidth: s(390)
    implicitHeight: body.height + s(root.pad * 2)

    property var claude: null        // { five_hour: { used_percentage, resets_at }, seven_day: … }
    property var codex: null         // { primary: { used_percent, window_minutes, resets_at }, secondary: … }
    property var agy: null           // { windows: [{ name, window, used_percent, resets_at }] }
    property var kiro: null          // same shape as agy
    property real now: Date.now() / 1000

    readonly property string stateDir:
        Config.stateHome + "/ai-usage"

    FileView {
        id: claudeFile
        path: root.stateDir + "/claude.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.claude = JSON.parse(text()); } catch (e) {} }
    }

    Poll {
        interval: 60000
        command: ["sh", "-c",
            'for f in $(ls -t "$HOME"/.codex/sessions/*/*/*/rollout-*.jsonl 2>/dev/null | head -5); do ' +
            'l=$(tac "$f" | grep -m1 \'"rate_limits":{\') && { printf "%s" "$l"; exit; }; done']
        onJsonData: v => {
            if (v && v.payload && v.payload.rate_limits) root.codex = v.payload.rate_limits;
        }
    }

    // `error` marks a run that gave nothing.
    Instantiator {
        model: [{ key: "agy", every: 300000 }, { key: "kiro", every: 900000 }]
        delegate: Poll {
            id: probe
            required property var modelData
            interval: probe.modelData.every
            command: ["python3", Quickshell.shellDir + "/scripts/ai-usage.py", probe.modelData.key]
            onJsonData: v => root[probe.modelData.key] = v || { error: "usage unavailable" }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = Date.now() / 1000
    }

    function windowName(minutes) {
        return minutes >= 1440 ? Math.round(minutes / 1440) + "d" : Math.round(minutes / 60) + "h";
    }

    function row(who, win, pct, resetsAt) {
        var left = (resetsAt || 0) - root.now;
        return { name: who + " " + win, pct: left > 0 ? pct : 0, left: left };
    }

    readonly property var rows: {
        var out = [];
        var c = root.claude;
        if (c && c.five_hour) out.push(row("Claude", "5h", c.five_hour.used_percentage, c.five_hour.resets_at));
        if (c && c.seven_day) out.push(row("Claude", "7d", c.seven_day.used_percentage, c.seven_day.resets_at));
        var x = root.codex;
        ["primary", "secondary"].forEach(function(k) {
            var w = x && x[k];
            if (w) out.push(row("Codex", windowName(w.window_minutes), w.used_percent, w.resets_at));
        });
        [root.agy, root.kiro].forEach(function(a) {
            if (a && a.windows) a.windows.forEach(function(w) {
                out.push(row(w.name, w.window, w.used_percent, w.resets_at));
            });
        });
        return out;
    }

    function countdown(s) {
        if (s <= 0) return "reset";
        var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? d + "d " + h + "h" : h + "h " + m + "m";
    }

    function tint(p) { return p >= 90 ? Theme.red : p >= 70 ? Theme.peach : Theme.green; }

    Column {
        id: body
        width: parent.width
        spacing: root.s(6)

        CardHeader {
            icon: "󰚩"
            iconColor: Theme.mauve
            label: "AI usage"
            Txt { font.pixelSize: root.s(14); text: root.rows.length ? "" : "no data" }
        }

        Repeater {
            model: root.rows
            delegate: Row {
                id: line
                required property var modelData
                width: body.width
                spacing: root.s(8)
                Txt {
                    id: nm
                    text: line.modelData.name
                    font.pixelSize: root.s(13)
                    width: root.s(150)
                    elide: Text.ElideRight
                }
                Gauge {
                    anchors.verticalCenter: parent.verticalCenter
                    width: line.width - nm.width - val.width - line.spacing * 2
                    fraction: Math.min(line.modelData.pct, 100) / 100
                    fillColor: root.tint(line.modelData.pct)
                }
                Txt {
                    id: val
                    width: root.s(100)
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: root.s(13)
                    color: root.tint(line.modelData.pct)
                    text: Math.round(line.modelData.pct) + "% · " + root.countdown(line.modelData.left)
                }
            }
        }

        Repeater {
            model: [{ label: "agy", key: "agy" }, { label: "Kiro", key: "kiro" }]
            delegate: Txt {
                id: miss
                required property var modelData
                readonly property var usage: root[miss.modelData.key]
                visible: !miss.usage || !!miss.usage.error
                font.pixelSize: root.s(13)
                color: Theme.subtext0
                text: miss.modelData.label + " · " + (miss.usage ? "usage unavailable" : "loading…")
            }
        }
    }
}
