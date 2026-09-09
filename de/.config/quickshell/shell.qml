import Quickshell

// Entry point. quickshell loads ~/.config/quickshell/shell.qml by default.
//
// One line per feature, gated by the catalogue in Config.qml (the switchboard):
// LazyLoader.active = Config.on("<key>"), so a feature toggled off is never built
// and costs zero RAM — and toggling one at runtime builds or tears it down live.
// To enable/disable a part, use the settings menu (Super+Shift+Escape), which writes
// ~/.local/state/quickshell/features.json — don't edit this file or Config.qml.
// (active: is synchronous, so it loads at startup without needing a window first.)
//
// The system tray has no line of its own: it lives in the status row of the
// bar now, gated by the same "tray" flag from inside Bar.qml.
//
// Settings is the one thing with no flag: it must always be built, or turning it
// off would leave no way to turn anything back on.
ShellRoot {
    Settings {}

    LazyLoader { active: Config.on("wallpaper");           WallpaperView {} }
    LazyLoader { active: Config.on("wallpaperPicker");     WallpaperPicker {} }
    LazyLoader { active: Config.on("notificationPopups");  NotificationPopups {} }
    LazyLoader { active: Config.on("clipboard");           Clipboard {} }
    LazyLoader { active: Config.on("launcher");            Launcher {} }
    LazyLoader { active: Config.on("session");             Session {} }
    LazyLoader { active: Config.on("audio");               Audio {} }
    LazyLoader { active: Config.on("bar");                 Bar {} }
    LazyLoader { active: Config.on("clock");               Clock {} }
    LazyLoader { active: Config.on("cpuGraph");            CpuGraph {} }
    LazyLoader { active: Config.on("netGraph");            NetGraph {} }
    LazyLoader { active: Config.on("ports");               Ports {} }
    LazyLoader { active: Config.on("vpn");                 Vpn {} }
    LazyLoader { active: Config.on("mpd");                 Mpd {} }
    LazyLoader { active: Config.on("weather");             Weather {} }
    LazyLoader { active: Config.on("notificationHistory"); Notifications {} }
    LazyLoader { active: Config.on("calendar");            Calendar {} }
    LazyLoader { active: Config.on("brightness");          Brightness {} }
    LazyLoader { active: Config.on("battery") && Config.batteryPresent; Battery {} }
    LazyLoader { active: Config.on("osd");                 Osd {} }
    LazyLoader { active: Config.on("spotlight");           Spotlight {} }
}
