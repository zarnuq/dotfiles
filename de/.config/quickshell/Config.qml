pragma Singleton
import Quickshell
import Quickshell.Io

// ─────────────────────────────────────────────────────────────────────────
//  The switchboard.  Every feature of the shell is listed once, here, and
//  turned on or off from the settings menu (Super+Shift+Escape / `qs ipc call
//  settings toggle`) — not by editing this file.
//
//  Which features are OFF is per-machine state kept OUTSIDE the repo, in
//  ~/.local/state/quickshell/features.json, so one stowed config serves every
//  box and each keeps its own set. Anything absent from that file is ON: a
//  fresh machine gets the whole shell, and the file only ever records what you
//  turned off. Delete it to get everything back.
//
//  shell.qml gates each feature with LazyLoader.active = Config.on("<key>"),
//  so a disabled part is never built — zero RAM, no daemons — and toggling one
//  builds or tears it down live, without restarting qs.
//
//  ADDING A FEATURE: one entry in `features` below, one LazyLoader line in
//  shell.qml. The menu is generated from this list, so there is no second
//  place to update.
// ─────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    // Which machine are we on? These dotfiles are shared between the desktop
    // (multi-monitor; mainScreen is its middle one) and the laptop (eDP-1 only),
    // so every "where do widgets go / how big are they" decision keys off
    // whether mainScreen is actually connected.
    property string mainScreen: "DP-2"

    /// The output with this name, or null if it isn't connected.
    // "Which monitor?" was asked from four places — the widget card's pin, the
    // picker's fallback, the notification popups' pin, and onLaptop itself —
    // and every one of them walked Quickshell.screens with its own loop.
    function screen(name) {
        var all = Quickshell.screens;
        for (var i = 0; i < all.length; i++)
            if (all[i].name === name) return all[i];
        return null;
    }

    readonly property bool onLaptop: root.screen(mainScreen) === null

    // The shell's one scale factor: the laptop's smaller panel gets everything
    // at 0.85, the desktop at 1.0. Widget applies it to its own children, and
    // the surfaces that aren't Widgets (bar, OSD, pickers) each used to carry a
    // private copy of exactly these two lines.
    readonly property real scale: root.onLaptop ? 0.85 : 1.0
    function s(n) { return Math.round(n * root.scale); }

    // The catalogue, in menu order. `group` only sets the headings.
    // The settings menu itself is deliberately absent: it is always built, or
    // turning it off would leave no way to turn anything back on.
    readonly property var features: [
        { key: "wallpaper",           group: "Background",  label: "Wallpaper" },
        { key: "wallpaperPicker",     group: "Background",  label: "Wallpaper picker" },

        { key: "notificationPopups",  group: "Notifications", label: "Popups (D-Bus server)" },
        { key: "notificationHistory", group: "Notifications", label: "History panel + DND" },

        { key: "osd",                 group: "Feedback",    label: "OSD (volume/mic/brightness)" },
        { key: "spotlight",           group: "Feedback",    label: "Cursor spotlight (shake)" },

        { key: "session",             group: "Session",     label: "Lock screen + idle lock" },
        { key: "clipboard",           group: "Session",     label: "Clipboard watchers" },
        { key: "launcher",            group: "Session",     label: "App launcher" },
        { key: "audio",               group: "Session",     label: "Audio mixer" },
        { key: "network",             group: "Session",     label: "Network menu" },

        { key: "bar",                 group: "Panel",       label: "Status bar" },
        { key: "clock",               group: "Panel",       label: "Clock" },
        { key: "cpuGraph",            group: "Panel",       label: "CPU / GPU / RAM / disk" },
        { key: "netGraph",            group: "Panel",       label: "Network" },
        { key: "ports",               group: "Panel",       label: "Listening ports" },
        { key: "vpn",                 group: "Panel",       label: "VPN" },
        { key: "mpd",                 group: "Panel",       label: "Now playing" },
        { key: "weather",             group: "Panel",       label: "Weather" },
        { key: "calendar",            group: "Panel",       label: "Calendar agenda" },
        { key: "brightness",          group: "Panel",       label: "Brightness" },
        { key: "battery",             group: "Panel",       label: "Battery (laptop only)" },
        { key: "tray",                group: "Panel",       label: "System tray" }
    ]

    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string statePath: stateDir + "/features.json"

    // Only the OFF switches are stored, so the file reads as a list of what
    // this machine doesn't want. In memory it's the same shape: absent = on.
    //
    // An initial binding rather than Component.onCompleted: the first thing to
    // touch this singleton is shell.qml's `active:` binding, and onCompleted
    // would run *after* that read — every disabled widget would be built and
    // then immediately torn down. As a binding the file is parsed during the
    // first read, so the very first answer is already the right one. Writing
    // through setEnabled() replaces the binding for good, which is what we want:
    // the menu owns the value from then on and setText() (async — text() lags a
    // tick) can never fight it.
    property var overrides: {
        var t = stateFile.text();
        if (!t) return ({});
        try {
            var parsed = JSON.parse(t);
            if (parsed && typeof parsed === "object") return parsed;
        } catch (e) {
            // A corrupt file must not take the shell down with it: fall back to
            // everything-on, which is also what a missing file means.
            console.warn("Config: ignoring unparseable " + root.statePath + ": " + e);
        }
        return ({});
    }

    function on(key) { return root.overrides[key] !== false; }

    function setEnabled(key, enabled) {
        // A fresh object, not a mutation: QML notifies on assignment only, and
        // every LazyLoader in shell.qml is watching this property.
        var next = {};
        for (var k in root.overrides) next[k] = root.overrides[k];
        if (enabled) delete next[key];
        else next[key] = false;

        root.overrides = next;
        stateFile.setText(JSON.stringify(next, null, 2) + "\n");
    }

    function toggle(key) { root.setEnabled(key, !root.on(key)); }

    // blockLoading: shell.qml reads these flags in the same frame it builds, so
    // an async read would build every widget and then tear the disabled ones
    // straight back down. printErrors: a missing file is the normal first-run
    // state, not an error — text() returns "" and everything stays on, and the
    // parent directory is created by the first write.
    // (Hand-edits to the file land on the next start or QML reload.)
    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }

    // Only the laptop has BAT0. Probed once at startup (blockLoading, so the
    // binding has a real answer by the time shell.qml reads it) — the desktop
    // then never builds the widget at all rather than building it and hiding
    // it, which is what every flag here buys you.
    FileView { id: batteryProbe; path: "/sys/class/power_supply/BAT0/capacity"; blockLoading: true; printErrors: false }
    readonly property bool batteryPresent: batteryProbe.text().trim().length > 0
}
