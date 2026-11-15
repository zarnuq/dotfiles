pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Claude + Codex rate-limit windows, bottom-right above the syncthing card.
//
// Neither source costs a network call. Claude Code only exposes its limits on
// the statusline's stdin, so `statusline-command.sh` mirrors them to
// ~/.local/state/ai-usage/claude.json and this card watches that file — the
// numbers move only while some Claude session is drawing a statusline. Codex
// writes `rate_limits` into its session rollouts; one `tac | grep -m1` over the
// newest few each minute reads the last snapshot (same source as
// ai-cli-subagents' delegate.py). A window whose reset time has passed is
// shown as 0 even when the snapshot is older than that.
Widget {
    id: root
    anchors { bottom: true; right: true }
    margins { bottom: Config.syncthingHeight + (Config.batteryPresent && Config.on("battery") ? s(75) : 0) }
    implicitWidth: s(300)
    implicitHeight: body.height + s(root.pad * 2)

    property var claude: null        // { five_hour: { used_percentage, resets_at }, seven_day: … }
    property var codex: null         // { primary: { used_percent, window_minutes, resets_at }, secondary: … }
    property real now: Date.now() / 1000

    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ai-usage"

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
            root.now = Date.now() / 1000;
            if (v && v.payload && v.payload.rate_limits) root.codex = v.payload.rate_limits;
        }
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
                Txt { id: nm; text: line.modelData.name; font.pixelSize: root.s(13); width: root.s(72) }
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
    }
}
