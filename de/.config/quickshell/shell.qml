import Quickshell

// Entry point. quickshell loads ~/.config/quickshell/shell.qml by default.
// One line per ported eww widget window.
ShellRoot {
    Clock {}
    CpuGraph {}
    NetGraph {}
    Ports {}
    Vpn {}
    Mpd {}
    Weather {}
    Notifications {}
    Calendar {}
    Brightness {}
    Tray {}
}
