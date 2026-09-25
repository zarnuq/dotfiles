pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Reactive system metrics (all 0..100 except temps), polled every 2s.
// Analog of eww's EWW_CPU/EWW_RAM/EWW_DISK magic vars + the nvidia-smi / thermal defpolls,
// but CPU and RAM are read straight from /proc (no subprocess) to show the "native" win.
Singleton {
    id: root

    property real cpu: 0
    property real ram: 0
    property real disk: 0
    property real gpu: 0
    property int cpuTemp: 0
    property int gpuTemp: 0

    // ---- native /proc reads (no fork/exec) -------------------------------
    property real _prevTotal: 0
    property real _prevIdle: 0

    FileView { id: statFile; path: "/proc/stat";    blockLoading: true }
    FileView { id: memFile;  path: "/proc/meminfo"; blockLoading: true }

    function readCpu() {
        statFile.reload();
        // first line: "cpu  user nice system idle iowait irq softirq steal ..."
        var f = statFile.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        var idle = f[3] + (f[4] || 0);
        var total = f.reduce(function (a, b) { return a + b; }, 0);
        var dt = total - root._prevTotal;
        var di = idle - root._prevIdle;
        if (root._prevTotal > 0 && dt > 0)
            root.cpu = Math.max(0, Math.min(100, (1 - di / dt) * 100));
        root._prevTotal = total;
        root._prevIdle = idle;
    }

    function readRam() {
        memFile.reload();
        var t = memFile.text();
        var total = Number(/MemTotal:\s+(\d+)/.exec(t)[1]);
        var avail = Number(/MemAvailable:\s+(\d+)/.exec(t)[1]);
        root.ram = (1 - avail / total) * 100;
    }

    // ---- battery ---------------------------------------------------------
    // upowerd isn't running on this box, so Quickshell.Services.UPower reports
    // nothing and the two sysfs files are the only source. The bar block and the
    // bottom-right card each kept their own FileView pair, their own timer and
    // their own copy of this parse, at two different intervals.
    // Whether there IS a battery is Config's one-shot probe of the same file,
    // asked once at startup where it cannot flap. Deriving it from each read is
    // what made the card and the bar block disappear mid-session: reload() is a
    // refresh, text() can come back empty while one is in flight, and a single
    // empty read set present=false — which, with the timer's `running` bound to
    // it, stopped the only thing that could ever set it back.
    readonly property bool batteryPresent: Config.batteryPresent
    property int batteryLevel: 100
    property string batteryStatus: "Unknown"

    // Whether a charger is attached is the MAINS supply's business, and
    // BAT0/status cannot answer it. With charge thresholds set (75/80 on this
    // laptop) the kernel reports `Not charging` for the whole time the charge
    // sits in that window on AC, and `Charging` only while it is actually
    // moving — so a plug state inferred from the battery read as "on battery"
    // for most of a plugged-in session: the card said "battery" in white with
    // the discharge glyph while the bar, which tested `!== "Discharging"`, drew
    // a plug. It also aimed the card's "plug in" toast at someone already
    // plugged in, since any `Not charging` under 20% (a charger too weak to
    // outpace the draw, charge_behaviour set to inhibit) satisfied !charging.
    //
    // Default true, and a failed read keeps the last good value: "unplugged" is
    // the direction that fires a critical notification, so it is never guessed.
    property bool onAc: true
    // Kept for what it actually names: charge moving upward. `Full` is on AC at
    // 100%, which is onAc, not charging.
    readonly property bool charging: batteryStatus === "Charging"

    FileView { id: capFile;  path: "/sys/class/power_supply/BAT0/capacity"; blockLoading: true; printErrors: false }
    FileView { id: battFile; path: "/sys/class/power_supply/BAT0/status";   blockLoading: true; printErrors: false }
    // `AC` is this laptop's mains name; other firmware calls it ACAD/AC0/ADP1.
    FileView { id: acFile;   path: "/sys/class/power_supply/AC/online";     blockLoading: true; printErrors: false }

    function readBattery() {
        capFile.reload();
        battFile.reload();
        acFile.reload();
        // Parsed ahead of the capacity guard below: the plug is independent of
        // the battery read, and it is what the low-charge latch turns on.
        var ac = acFile.text().trim();
        if (ac.length > 0)
            root.onAc = ac !== "0";
        // An empty or non-numeric read is a read that didn't land, not a battery
        // that vanished: keep the last good values rather than letting Number("")
        // report a fake 0%.
        var cap = capFile.text().trim();
        if (cap.length === 0 || isNaN(Number(cap))) return;
        root.batteryLevel = Number(cap);
        root.batteryStatus = battFile.text().trim();
    }

    // Its own tick: charge doesn't move on the 2s beat the graphs need. Gated
    // on the startup probe, so the desktop never runs it at all and the laptop
    // never stops — the gate and the value it reads must not be the same thing.
    Component.onCompleted: root.readBattery()
    Timer {
        interval: 10000
        running: root.batteryPresent
        repeat: true
        onTriggered: root.readBattery()
    }

    // ---- external tools (need the binary; run as short-lived processes) ---
    // No nvidia, no nvidia-smi: without this the tick forks a process that can
    // only fail, every 2s for the life of the session (~43k times a day on the
    // laptop). Same trick as Config's BAT0 probe — ask the kernel once.
    FileView { id: nvidiaProbe; path: "/proc/driver/nvidia/version"; blockLoading: true; printErrors: false }
    readonly property bool gpuPresent: nvidiaProbe.text().length > 0

    // Poll's default interval is the same 2s beat as the /proc reads below.
    Poll {
        running: root.gpuPresent
        command: ["nvidia-smi",
                  "--query-gpu=utilization.gpu,temperature.gpu",
                  "--format=csv,noheader,nounits"]
        onData: text => {
            var p = text.trim().split(",");
            root.gpu = Number(p[0]) || 0;
            root.gpuTemp = Number(p[1]) || 0;
        }
    }

    Poll {
        command: ["sh", "-c", "df -P / | awk 'NR==2{gsub(\"%\",\"\",$5); print $5}'"]
        onData: text => root.disk = Number(text.trim()) || 0
    }

    Poll {
        command: ["sh", "-c",
            "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | awk '{s+=$1;n++} END{if(n)printf \"%.0f\", s/n/1000}'"]
        onData: text => root.cpuTemp = Number(text.trim()) || 0
    }

    Timer {
        interval: 2000          // eww polled these at 2s
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { root.readCpu(); root.readRam(); }
    }
}
