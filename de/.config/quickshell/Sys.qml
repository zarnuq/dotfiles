pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Reactive system metrics (all 0..100 except temps), polled every 2s.
// Analog of eww's EWW_CPU/EWW_RAM/EWW_DISK magic vars + the nvidia-smi / thermal defpolls,
// but CPU and RAM are read straight from /proc (no subprocess) to show the "native" win.
//
// Only the CPU card reads this, and a singleton is built on first reference —
// so a machine with that card off never runs any of it. The battery lives in
// Power for exactly that reason: the bar reads it everywhere.
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

    function readRam(): void {
        memFile.reload();
        var t = memFile.text();
        var total = Number(/MemTotal:\s+(\d+)/.exec(t)[1]);
        var avail = Number(/MemAvailable:\s+(\d+)/.exec(t)[1]);
        root.ram = (1 - avail / total) * 100;
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

    // Use% of `/`: line 2, column 5 ("42%"). Parsed here rather than by a
    // shell pipeline, which cost an sh and an awk on every tick.
    Poll {
        command: ["df", "-P", "/"]
        onData: text => {
            var f = (text.split("\n")[1] || "").trim().split(/\s+/);
            root.disk = parseInt(f[4]) || 0;
        }
    }

    // Mean of every thermal zone, in millidegrees. The shell is only there for
    // the glob.
    Poll {
        command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null"]
        onData: text => {
            var t = text.split("\n").filter(l => l.trim() !== "").map(Number);
            root.cpuTemp = t.length ? Math.round(t.reduce((a, b) => a + b, 0) / t.length / 1000) : 0;
        }
    }

    Timer {
        interval: 2000          // eww polled these at 2s
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { root.readCpu(); root.readRam(); }
    }
}
