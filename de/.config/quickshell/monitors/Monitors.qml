pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
        function identify(): void { root.identify(); }
    }

    // ---- identify -----------------------------------------------------------
    // Windows' "Identify": every head shows its output name — what the canvas
    // boxes are labelled with — for a few seconds. Works with the window closed
    // too, via IPC.
    property bool identifying: false
    function identify(): void {
        root.identifying = true;
        identifyTimer.restart();
    }
    Timer {
        id: identifyTimer
        interval: 3000
        onTriggered: root.identifying = false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: badge
            required property var modelData
            screen: modelData
            visible: root.identifying

            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            // No anchors: layer-shell centres an unanchored surface. An empty
            // mask makes it click-through, so it can't eat the click that
            // follows — it is a label, not a dialog.
            mask: Region {}
            // Sized to the name: "eDP-1" and "HDMI-A-1" are very different widths.
            implicitWidth: label.implicitWidth + Config.s(80)
            implicitHeight: label.implicitHeight + Config.s(60)

            Rectangle {
                anchors.fill: parent
                color: Theme.base
                border.color: Theme.mauve
                border.width: Config.s(2)
                radius: Theme.borderRadius

                Column {
                    id: label
                    anchors.centerIn: parent
                    spacing: Config.s(4)
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: badge.modelData.name
                        color: Theme.mauve
                        font.pixelSize: Config.s(72)
                        font.bold: true
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: badge.modelData.width + "×" + badge.modelData.height
                        color: Theme.subtext0
                        font.pixelSize: Config.s(13)
                    }
                }
            }
        }
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
            anchors.fill: parent
            active: root.open
            sourceComponent: MonitorsView {
                onCloseRequested: root.open = false
                onIdentifyRequested: root.identify()
            }
            onLoaded: item.reload()
        }
    }
}
