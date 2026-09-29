pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// The battery and the mains supply, for the bar's battery block and the
// bottom-right card.
//
// upowerd isn't running on this box, so Quickshell.Services.UPower reports
// nothing and sysfs is the only source. This used to be a section of Sys, which
// meant the bar — built on every machine — instantiated the CPU/RAM/disk/GPU
// metrics too, and with them a 2s timer and three forking polls that nothing
// with the CPU card switched off ever read.
Singleton {
    id: root

    // Whether there IS a battery is Config's one-shot probe of the same file,
    // asked once at startup where it cannot flap. Deriving it from each read is
    // what made the card and the bar block disappear mid-session: reload() is a
    // refresh, text() can come back empty while one is in flight, and a single
    // empty read set present=false — which, with the timer's `running` bound to
    // it, stopped the only thing that could ever set it back.
    readonly property bool present: Config.batteryPresent
    property int level: 100
    property string status: "Unknown"

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
    readonly property bool charging: status === "Charging"

    FileView { id: capFile;  path: "/sys/class/power_supply/BAT0/capacity"; blockLoading: true; printErrors: false }
    FileView { id: battFile; path: "/sys/class/power_supply/BAT0/status";   blockLoading: true; printErrors: false }
    // `AC` is this laptop's mains name; other firmware calls it ACAD/AC0/ADP1.
    FileView { id: acFile;   path: "/sys/class/power_supply/AC/online";     blockLoading: true; printErrors: false }

    function read(): void {
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
        root.level = Number(cap);
        root.status = battFile.text().trim();
    }

    // Charge doesn't move on the 2s beat the graphs need. Gated on the startup
    // probe, so the desktop never runs it at all and the laptop never stops —
    // the gate and the value it reads must not be the same thing.
    Component.onCompleted: if (root.present) root.read()
    Timer {
        interval: 10000
        running: root.present
        repeat: true
        onTriggered: root.read()
    }
}
