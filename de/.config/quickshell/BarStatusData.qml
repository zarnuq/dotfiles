import Quickshell
import QtQuick

// One set of status readings for all outputs, owned by Bar's feature loader.
Scope {
    id: root

    property string clock: ""
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // date '+%a %m/%d %I:%M %p'
            var d = new Date();
            var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            var h12 = d.getHours() % 12;
            if (h12 === 0)
                h12 = 12;
            root.clock = days[d.getDay()] + " " + root.p2(d.getMonth() + 1) + "/" + root.p2(d.getDate()) + " " + root.p2(h12) + ":" + root.p2(d.getMinutes()) + " " + (d.getHours() < 12 ? "AM" : "PM");
        }
    }
    function p2(n) {
        return ("" + n).padStart(2, "0");
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
        command: ["sh", "-c", "iface=$(ip route show default 2>/dev/null | awk '/default/ { print $5; exit }'); " + "[ -z \"$iface\" ] && { echo 'no link'; exit; }; " + "addr=$(ip -4 addr show \"$iface\" | awk '/inet / { print $2 }' | cut -d/ -f1); " + "[ -z \"$addr\" ] && { echo 'no ip'; exit; }; echo \" $iface: $addr\""]
        interval: 30000
        onData: text => root.ip = text.trim()
    }

    // Sys owns the battery poll shared with the battery card.
    readonly property string batteryGlyph: {
        if (Sys.batteryStatus === "Charging")
            return "";
        if (Sys.batteryStatus !== "Discharging")
            return "";
        if (Sys.batteryLevel <= 10)
            return "";
        if (Sys.batteryLevel <= 25)
            return "";
        if (Sys.batteryLevel <= 50)
            return "";
        if (Sys.batteryLevel <= 75)
            return "";
        return "";
    }
}
