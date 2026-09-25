import Quickshell
import Quickshell.Io
import QtQuick
// Parent import: `Txt` (and the root singletons) live one level up. A QML
// file does NOT see its parent directory implicitly — only its own.
import ".."

// Music window (Super+Shift+M / `qs ipc call music toggle`). Reach tiles this
// toplevel using its org.quickshell app_id; additional toplevels would need a
// title-specific rule. The service disables Qt's window decorations.
// The Loader releases the queue delegates and controller when the window closes.
Scope {
    id: root

    property bool open: false

    // No `show`: `qs ipc call <target> show` collides with the `qs ipc show`
    // subcommand — the CLI prints the target listing and never reaches the
    // handler. Same reason Picker exposes only these two.
    IpcHandler {
        target: "music"
        function toggle(): void { root.open = !root.open; }
        function hide(): void   { root.open = false; }
        // See Picker: `open` is the non-colliding name for "up regardless",
        // which is what the launcher's ">" menu list needs. The window is the
        // case that makes it matter — unlike an overlay it really can be
        // sitting open behind the launcher.
        function open(): void   { root.open = true; }
    }

    FloatingWindow {
        id: win

        visible: root.open
        title: "Music"
        color: Theme.base

        implicitWidth: Config.s(1100)
        implicitHeight: Config.s(700)
        minimumSize: Qt.size(Config.s(560), Config.s(360))

        // Keep IPC state in sync when the window manager closes the surface.
        onClosed: root.open = false

        Loader {
            id: view
            anchors.fill: parent
            active: root.open
            // Hold the queue only while the window is up; MpdClient drops it on
            // release, so a closed player costs nothing but its two sockets.
            onActiveChanged: {
                if (active) MpdClient.retainQueue();
                else MpdClient.releaseQueue();
            }
            sourceComponent: MusicView {
                onCloseRequested: root.open = false
            }
            onLoaded: item.reset()
        }
    }
}
