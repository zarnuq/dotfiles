pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// One set of status readings for all outputs, owned by Bar's feature loader.
Scope {
    id: root

    property string clock: ""
    // date '+%a %m/%d %I:%M %p' — `hh` is 12-hour because `AP` is present.
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.clock = Qt.formatDateTime(new Date(), "ddd MM/dd hh:mm AP")
    }

    // audio.sh's sed, ported: drop the parenthetical, then the boilerplate words
    // that every ALSA description carries, then squeeze the leftover spaces.
    readonly property string sinkName: {
        var d = Volume.sinkName;
        return d.replace(/\([^)]*\)/g, "").replace(/\b(Analog|HD|Audio|17h|19h|1ah|Digital|Stereo|Mono|Controller|Family|Surround|Sink|Output|A2DP|Pro|Profile|HDMI)\b/gi, "").replace(/\//g, "").replace(/ +/g, " ").trim();
    }

    // ip.sh: the address of whatever interface owns the default route.
    property string ip: "no link"
    Poll {
        command: ["sh", "-c", "iface=$(ip route show default 2>/dev/null | awk '/default/ { print $5; exit }'); "
                  + "[ -z \"$iface\" ] && { echo 'no link'; exit; }; "
                  + "addr=$(ip -4 addr show \"$iface\" | awk '/inet / { print $2 }' | cut -d/ -f1); "
                  + "[ -z \"$addr\" ] && { echo 'no ip'; exit; }; echo \" $iface: $addr\""]
        interval: 30000
        onData: text => root.ip = text.trim()
    }

    // Connected Bluetooth devices' names, "" when none (the block hides).
    // Event-driven rather than polled, because the bar is always up: `gdbus
    // monitor` prints a line per BlueZ signal and only one about Connected or
    // Powered re-reads the list (debounced — a connect is a burst of signals),
    // so an idle bar forks nothing. No adapter or no bluetoothd: gdbus exits,
    // the list is empty, and the retry timer tries again every 30s.
    property string bluetooth: ""
    Poll {
        id: btList
        running: false
        command: ["sh", "-c", "bluetoothctl devices Connected | cut -d' ' -f3-"]
        onData: text => root.bluetooth = text.trim().split("\n").filter(s => s).join(", ")
        Component.onCompleted: refresh()
    }
    Timer { id: btSettle; interval: 500; onTriggered: btList.refresh() }
    Process {
        id: btMon
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.bluez"]
        stdout: SplitParser { onRead: line => { if (/Connected|Powered/.test(line)) btSettle.restart(); } }
    }
    Timer { interval: 30000; running: !btMon.running; onTriggered: btMon.running = true }

    // Power owns the battery read shared with the battery card.
    //
    // The glyph tracks the LEVEL; whether a charger is in is carried by the
    // color in BarStatus (green charging, teal held on mains). The old branch
    // here drew a FULL battery for every state that wasn't `Discharging`, so a
    // charge-threshold hold at 30% on AC read as a full battery.
    readonly property string batteryGlyph: Power.charging ? ""
        : Power.level <= 10 ? ""
        : Power.level <= 25 ? ""
        : Power.level <= 50 ? ""
        : Power.level <= 75 ? ""
        : ""
}
