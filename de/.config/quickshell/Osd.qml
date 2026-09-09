import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Transient indicator for volume / mic / brightness / default-sink changes.
//
// The gap it fills: the only feedback for Alt+Up/Down (volume), Alt+Left/Right
// (mic) and Super+Alt+Left/Right (brightness) was reach's status bar, which
// lives on one monitor — press a key while looking at another and nothing
// visibly happened. Alt+[ (flip.sh) was worse: it cycles the default sink
// blind, so the only way to learn where audio went was to play something.
//
// Drawn on EVERY output, not the focused one. reach exposes no IPC naming the
// focused monitor, and the pointer-containment trick Picker.qml uses needs a
// full-screen surface — which would swallow clicks the whole time it's mapped.
// Each window here is only as big as the indicator and only mapped while shown,
// so it never eats input.
//
// Nothing polls: volume/mic ride the Volume singleton's properties (Pipewire's
// own signals underneath), brightness tails wl-gammarelay's PropertiesChanged,
// and the sink label falls out of Volume.sink changing identity.
Scope {
    id: root

    readonly property real scale: Config.scale
    function s(n) { return Config.s(n); }

    property string icon: ""
    property string label: ""      // sink mode: shown instead of the bar
    property int level: 0
    property bool muted: false
    property bool showBar: true
    property bool shown: false

    // Pipewire delivers initial values as it binds the nodes, and gdbus prints a
    // banner line on connect; without this the shell would flash an OSD every
    // start and every config reload.
    property bool ready: false
    Timer { interval: 1500; running: true; onTriggered: root.ready = true }

    Timer { id: linger; interval: 1600; onTriggered: root.shown = false }

    // Switching sinks changes the volume too. Without this the volume OSD would
    // paint over the sink name in the same frame you asked for it.
    property bool sinkGuard: false
    Timer { id: guard; interval: 500; onTriggered: root.sinkGuard = false }

    function flash(icon, level, muted) {
        if (!root.ready) return;
        root.icon = icon; root.level = level; root.muted = muted;
        root.showBar = true; root.shown = true;
        linger.restart();
    }

    function flashText(icon, label) {
        if (!root.ready) return;
        root.icon = icon; root.label = label; root.muted = false;
        root.showBar = false; root.shown = true;
        linger.restart();
    }

    // ---- audio ------------------------------------------------------------
    // The devices and their numbers come from the Volume singleton, which is
    // also what keeps them bound; this file only decides when to flash. Watching
    // the singleton's plain properties rather than each node's audio object also
    // means there is no target to re-bind when the default device changes.
    function volumeFlash() {
        if (root.sinkGuard || !Volume.sink) return;
        root.flash(Volume.muted ? "󰖁" : "󰕾", Volume.volume, Volume.muted);
    }
    function micFlash() {
        if (!Volume.source) return;
        root.flash(Volume.micMuted ? "󰍭" : "󰍬", Volume.micVolume, Volume.micMuted);
    }

    Connections {
        target: Volume
        // A new default sink names itself instead of showing a level: switching
        // sinks changes the volume too, and sinkGuard is what stops the level
        // OSD from painting over the name in the same frame.
        function onSinkChanged() {
            if (!Volume.sink) return;
            root.sinkGuard = true;
            guard.restart();
            root.flashText("󰓃", Volume.sinkName);
        }
        function onVolumeChanged() { root.volumeFlash(); }
        function onMutedChanged() { root.volumeFlash(); }
        function onMicVolumeChanged() { root.micFlash(); }
        function onMicMutedChanged() { root.micFlash(); }
    }

    // ---- brightness -------------------------------------------------------
    // brightness.sh drives wl-gammarelay's Brightness property; tailing the
    // bus means the OSD tracks it however it was set (keybind, widget slider),
    // with none of the 2s lag Brightness.qml's poll would give a keypress.
    Process {
        running: true
        command: ["gdbus", "monitor", "--session", "--dest", "rs.wl-gammarelay"]
        stdout: SplitParser {
            onRead: function (data) {
                var m = /'Brightness': <([0-9.]+)>/.exec(data);
                if (m) root.flash("󰃟", Math.round(Number(m[1]) * 100), false);
            }
        }
        onExited: running = true
    }

    // ---- surface ----------------------------------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.shown

            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            // Top-right, cleared of reach's status bar along the top edge.
            anchors { top: true; right: true }
            margins { top: root.s(44); right: root.s(24) }
            implicitWidth: root.s(360)
            implicitHeight: root.s(84)

            Rectangle {
                anchors.fill: parent
                color: Theme.base
                border.color: Theme.surface0
                border.width: root.s(1)
                radius: Theme.borderRadius

                Row {
                    anchors.fill: parent
                    anchors.margins: root.s(18)
                    spacing: root.s(16)

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.s(30)
                        text: root.icon
                        color: root.muted ? Theme.red : Theme.text
                        font.pixelSize: root.s(26)
                    }

                    // Level modes: track + fill + percentage.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showBar
                        width: parent.width - root.s(30) - root.s(56) - parent.spacing * 2
                        height: root.s(8)
                        color: Theme.surface0
                        radius: Theme.borderRadius

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, root.level)) / 100
                            height: parent.height
                            color: root.muted ? Theme.red : Theme.mauve
                            radius: Theme.borderRadius
                        }
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showBar
                        width: root.s(56)
                        horizontalAlignment: Text.AlignRight
                        text: root.level + "%"
                        color: root.muted ? Theme.red : Theme.subtext0
                        font.pixelSize: root.s(18)
                    }

                    // Sink mode: just the device name.
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.showBar
                        width: parent.width - root.s(30) - parent.spacing
                        elide: Text.ElideRight
                        text: root.label
                        font.pixelSize: root.s(20)
                    }
                }
            }
        }
    }
}
