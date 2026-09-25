import Quickshell
import Quickshell.Io
import QtQuick
// Parent import: Theme/Config/Txt live one level up, and a QML file does not see
// its parent directory implicitly.
import ".."

// Display configurator (`Super+R` `m` / `qs ipc call monitors toggle`).
//
// A WINDOW, not a picker overlay, for the same reason the music player is one:
// arranging screens is a task you sit in, resize, and keep open beside something
// else — and a full-screen overlay would swallow every click for as long as it is
// mapped. reach tiles it by the shared `org.quickshell` app_id, so config.zon
// narrows the rule by title ("Displays").
//
// It edits reach's monitors.zon through scripts/monitors.py and applies by
// SIGHUP. Nothing here talks to the compositor: reach's state socket is
// deliberately write-only, and wlr-output-management changes made behind reach's
// back would be undone by its next reload anyway. The file IS the state, which
// is also what makes a layout survive a restart.
Scope {
    id: root

    property bool open: false

    // No `show`: `qs ipc call <target> show` collides with the `qs ipc show`
    // subcommand — the CLI prints the target listing and never reaches the
    // handler.
    IpcHandler {
        target: "monitors"
        function toggle(): void { root.open = !root.open; }
        function hide(): void   { root.open = false; }
        // See Picker: `open` is the non-colliding name for "up regardless",
        // which is what the launcher's ">" menu list needs — a window really
        // can be sitting open behind the launcher, and toggle would shut it.
        function open(): void   { root.open = true; }
    }

    FloatingWindow {
        id: win

        visible: root.open
        title: "Displays"
        color: Theme.base

        implicitWidth: Config.s(1000)
        implicitHeight: Config.s(680)
        minimumSize: Qt.size(Config.s(620), Config.s(460))

        // Keep IPC state in sync when the window manager closes the surface.
        onClosed: root.open = false

        // Built on open and destroyed on close: the view holds a working copy of
        // the layout, and a closed window must not keep one — reopening has to
        // show what is on disk now, not what was abandoned last time.
        Loader {
            id: view
            anchors.fill: parent
            active: root.open
            sourceComponent: MonitorsView {
                onCloseRequested: root.open = false
            }
            onLoaded: item.reload()
        }
    }
}
