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
    property bool batteryPresent: false
    property int batteryLevel: 100
    property string batteryStatus: "Unknown"
    readonly property bool charging: batteryStatus === "Charging" || batteryStatus === "Full"

    FileView { id: capFile;  path: "/sys/class/power_supply/BAT0/capacity"; blockLoading: true; printErrors: false }
    FileView { id: battFile; path: "/sys/class/power_supply/BAT0/status";   blockLoading: true; printErrors: false }

    function readBattery() {
        capFile.reload();
        battFile.reload();
        // A missing or unreadable battery reads back empty; treat that as "no
        // battery" rather than letting Number("") land on a fake 0%.
        var cap = capFile.text().trim();
        if (cap.length === 0 || isNaN(Number(cap))) { root.batteryPresent = false; return; }
        root.batteryPresent = true;
        root.batteryLevel = Number(cap);
        root.batteryStatus = battFile.text().trim();
    }

    // Its own tick: charge doesn't move on the 2s beat the graphs need.
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.readBattery()
    }

    // ---- external tools (need the binary; run as short-lived processes) ---
    Process {
        id: gpuProc
        command: ["nvidia-smi",
                  "--query-gpu=utilization.gpu,temperature.gpu",
                  "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(",");
                root.gpu = Number(p[0]) || 0;
                root.gpuTemp = Number(p[1]) || 0;
            }
        }
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -P / | awk 'NR==2{gsub(\"%\",\"\",$5); print $5}'"]
        stdout: StdioCollector { onStreamFinished: root.disk = Number(text.trim()) || 0 }
    }

    Process {
        id: cpuTempProc
        command: ["sh", "-c",
            "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | awk '{s+=$1;n++} END{if(n)printf \"%.0f\", s/n/1000}'"]
        stdout: StdioCollector { onStreamFinished: root.cpuTemp = Number(text.trim()) || 0 }
    }

    Timer {
        interval: 2000          // eww polled these at 2s
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.readCpu();
            root.readRam();
            gpuProc.running = true;
            diskProc.running = true;
            cpuTempProc.running = true;
        }
    }
}
