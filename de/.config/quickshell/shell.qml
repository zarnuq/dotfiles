import Quickshell

// Entry point. quickshell loads ~/.config/quickshell/shell.qml by default.
//
// One line per feature. Each is gated by a flag in Config.qml (the switchboard):
// LazyLoader.active = Config.<flag>, so a feature toggled off is never built and
// costs zero RAM. To enable/disable a part, edit Config.qml — not this file.
// (active: is synchronous, so it loads at startup without needing a window first.)
ShellRoot {
    LazyLoader { active: Config.wallpaper;           WallpaperView {} }
    LazyLoader { active: Config.notificationPopups;  NotificationPopups {} }
    LazyLoader { active: Config.lock;                Lock {} }
    LazyLoader { active: Config.clipboard;           Clipboard {} }
    LazyLoader { active: Config.launcher;            Launcher {} }
    LazyLoader { active: Config.clock;               Clock {} }
    LazyLoader { active: Config.cpuGraph;            CpuGraph {} }
    LazyLoader { active: Config.netGraph;            NetGraph {} }
    LazyLoader { active: Config.ports;               Ports {} }
    LazyLoader { active: Config.vpn;                 Vpn {} }
    LazyLoader { active: Config.mpd;                 Mpd {} }
    LazyLoader { active: Config.weather;             Weather {} }
    LazyLoader { active: Config.notificationHistory; Notifications {} }
    LazyLoader { active: Config.calendar;            Calendar {} }
    LazyLoader { active: Config.brightness;          Brightness {} }
    LazyLoader { active: Config.tray;                Tray {} }
}
