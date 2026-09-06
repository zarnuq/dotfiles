pragma Singleton
import Quickshell
import Quickshell.Io

// ─────────────────────────────────────────────────────────────────────────
//  The switchboard.  This is the ONLY file you edit to turn parts of the
//  shell on or off.  Flip a flag to false and that feature is never built
//  (shell.qml gates each one with LazyLoader.active) — so a disabled part
//  costs zero RAM and starts no daemons.  After editing: sv restart quickshell.
// ─────────────────────────────────────────────────────────────────────────
Singleton {
    // Which machine are we on? These dotfiles are shared between the desktop
    // (multi-monitor; mainScreen is its middle one) and the laptop (eDP-1 only),
    // so every "where do widgets go / how big are they" decision keys off
    // whether mainScreen is actually connected.
    property string mainScreen: "DP-2"
    readonly property bool onLaptop: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === mainScreen) return false;
        return true;
    }

    // Background
    property bool wallpaper: true            // per-screen wallpaper (replaces awww)
    property bool wallpaperPicker: true      // thumbnail grid picker (`qs ipc call wallpaperpicker toggle`)

    // Notifications
    property bool notificationPopups: true   // toast daemon / D-Bus server (replaces mako)
    property bool notificationHistory: true  // history panel + DND toggle widget

    // Feedback
    property bool osd: true                  // transient volume/mic/brightness/sink indicator

    // Session
    property bool lock: true // idle-lock + lock screen (replaces swayidle/swaylock)
    property bool clipboard: true            // cliphist text+image watchers (replaces the cliphist service)
    property bool launcher: true             // drun app launcher (replaces rofi; `qs ipc call launcher toggle`)
    property bool calendarWeek: true         // Outlook-style week grid overlay (`qs ipc call calendar toggle`)
    property bool powerMenu: true            // lock/logout/reboot/poweroff (`qs ipc call power toggle`)

    // Ambient widgets (the DP-2 panel)
    property bool clock: true
    property bool cpuGraph: true             // cpu/gpu/ram/disk graphs
    property bool netGraph: true             // net throughput + IPs
    property bool ports: true                // listening ports
    property bool vpn: true                  // OpenVPN control
    property bool mpd: true                  // now-playing
    property bool weather: true
    property bool calendar: true
    property bool brightness: true
    property bool battery: true          // charge level + low-battery warning (laptop only)
    property bool tray: true                 // system tray

    // Only the laptop has BAT0. Probed once at startup (blockLoading, so the
    // binding has a real answer by the time shell.qml reads it) — the desktop
    // then never builds the widget at all rather than building it and hiding
    // it, which is what every other flag here buys you.
    FileView { id: batteryProbe; path: "/sys/class/power_supply/BAT0/capacity"; blockLoading: true; printErrors: false }
    readonly property bool batteryPresent: batteryProbe.text().trim().length > 0
}
