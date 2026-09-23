import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// The mixer: output devices, input devices, and a volume slider per playing
// app. Replaces the `kitty --class float -e pulsemixer` that Super+R A used to
// spawn — same key, no terminal, and it reads the graph quickshell is already
// bound to instead of a second client.
//
// Built on Picker, so overlay/keyboard-focus/IPC come from the same place as
// the launcher and the session menu; this file is the list and the wiring.
Picker {
    id: root

    ipcTarget: "audio"

    // Nodes only publish `.audio` (and their properties) while something holds
    // a binding on them, and the menu has to be correct in the frame it opens —
    // so the tracker stays armed rather than being gated on `open`. It's ~16
    // nodes of bookkeeping, no polling.
    PwObjectTracker { objects: Pipewire.nodes.values }

    function cls(n) { return (n && n.properties) ? (n.properties["media.class"] || "") : ""; }
    function app(n) { return (n && n.properties) ? (n.properties["application.name"] || "") : ""; }

    // media.class rather than isSink/isStream: a playback stream reports
    // isSink true as well (it feeds one), so the flags alone can't tell an
    // output device from an app playing to it.
    rows: {
        var all = Pipewire.nodes.values;
        var sinks = [], sources = [], streams = [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (!n.audio) continue;
            var c = root.cls(n);
            if (c === "Audio/Sink") sinks.push(n);
            else if (c === "Audio/Source") sources.push(n);
            // The EQ filter-chains and the mic loopback are Stream/Output/Audio
            // too. They carry no application.name, which is exactly what
            // separates plumbing from something you'd actually want to turn down.
            else if (c === "Stream/Output/Audio" && root.app(n) !== "") streams.push(n);
        }

        var r = [];
        function section(title, nodes, kind) {
            if (nodes.length === 0) return;
            r.push({ kind: "header", label: title });
            for (var j = 0; j < nodes.length; j++)
                r.push({ kind: kind, node: nodes[j] });
        }
        section("Output", sinks, "sink");
        section("Input", sources, "source");
        section("Playing", streams, "stream");
        return r;
    }

    function label(row) {
        var n = row.node;
        if (row.kind === "stream")
            return root.app(n) + (n.properties && n.properties["media.name"]
                                  ? " — " + n.properties["media.name"] : "");
        return n.description || n.nickname || n.name;
    }

    function isDefault(row) {
        if (row.kind === "sink")   return Pipewire.defaultAudioSink === row.node;
        if (row.kind === "source") return Pipewire.defaultAudioSource === row.node;
        return false;
    }

    rowHeight: s(40)
    minBoxHeight: s(120)
    boxWidth: s(560)

    // A volume write reaches the row's `audio.volume` again only once Pipewire
    // has applied it and told us, so a slider bound straight to that property
    // trails the pointer by a round trip — which is what made dragging feel
    // late. The wanted value is held here and drawn immediately, and the writes
    // themselves are throttled: a drag emits one mouse move per frame, and
    // every one of those was a graph update.
    property var volNode: null
    property real volWanted: -1
    property real volSent: -1

    function levelOf(node) {
        if (!node || !node.audio) return 0;
        return (node === root.volNode && root.volWanted >= 0) ? root.volWanted : node.audio.volume;
    }

    function setVolume(row, v) {
        if (!row.node || !row.node.audio) return;
        if (root.volNode !== row.node) { root.volNode = row.node; root.volSent = -1; }
        root.volWanted = Math.max(0, Math.min(1, v));
        if (!volFlush.running) root.writeVolume();
    }

    function writeVolume() {
        if (!root.volNode || !root.volNode.audio) return;
        volSettle.stop();
        root.volNode.audio.volume = root.volWanted;
        root.volSent = root.volWanted;
        volFlush.restart();
    }

    Timer {
        id: volFlush
        interval: 40
        onTriggered: {
            if (root.volWanted !== root.volSent) root.writeVolume();
            else volSettle.restart();
        }
    }
    // Hand the row back to the graph once it has had time to echo the last
    // write; releasing immediately would snap the slider to the stale value.
    Timer {
        id: volSettle
        interval: 200
        onTriggered: { root.volNode = null; root.volWanted = -1; root.volSent = -1; }
    }

    function nudge(i, delta) {
        if (!selectable(i)) return;
        var row = rows[i];
        // Off the wanted level, not the echoed one, or held keys lose steps.
        if (row.node && row.node.audio) root.setVolume(row, root.levelOf(row.node) + delta);
    }
    function toggleMute(i) {
        if (!selectable(i)) return;
        var n = rows[i].node;
        if (n && n.audio) n.audio.muted = !n.audio.muted;
    }

    function activate(i) {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.kind === "stream") { root.toggleMute(i); return; }

        root.hide();
        if (row.kind === "source") {
            Pipewire.preferredDefaultAudioSource = row.node;
            return;
        }
        // Sinks go through flip.sh instead of preferredDefaultAudioSink: picking
        // the optical chain needs the PCH card flipped to an iec958 profile
        // first, and already-playing streams have to be moved by hand (a new
        // default only catches future ones). That logic already lives in the
        // script Alt+[ uses — duplicating it here would let the two drift.
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/flip.sh", "set", row.node.name]);
    }

    box: Component {
        Item {
            id: content
            focus: true

            Keys.onPressed: function (e) {
                if (root.navKey(e)) return;
                var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier));
                if (e.key === Qt.Key_M && plain) { root.toggleMute(root.selected); }
                else if (e.key === Qt.Key_Right || (e.key === Qt.Key_L && plain)) {
                    root.nudge(root.selected, 0.05);
                } else if (e.key === Qt.Key_Left || (e.key === Qt.Key_H && plain)) {
                    root.nudge(root.selected, -0.05);
                } else { return; }
                e.accepted = true;
            }

            Column {
                anchors.fill: parent
                anchors.topMargin: root.s(12)
                anchors.bottomMargin: root.s(12)
                spacing: 0

                Repeater {
                    model: root.rows

                    PickerRow {
                        id: rowItem
                        picker: root
                        readonly property var audio: isHeader ? null : modelData.node.audio
                        readonly property bool muted: audio ? audio.muted : false
                        readonly property int pct: audio ? Math.round(root.levelOf(modelData.node) * 100) : 0
                        readonly property bool isDefault: !isHeader && root.isDefault(modelData)

                        width: content.width
                        headerHeight: root.headerHeight
                        rowHeight: root.rowHeight
                        current: rowItem.isDefault
                        onActivated: root.activate(rowItem.index)

                        Row {
                            visible: !rowItem.isHeader
                            anchors.fill: parent
                            anchors.leftMargin: root.s(18)
                            anchors.rightMargin: root.s(18)
                            spacing: root.s(12)

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.s(24)
                                text: {
                                    if (rowItem.isHeader) return "";
                                    if (rowItem.modelData.kind === "source") return rowItem.muted ? "󰍭" : "󰍬";
                                    if (rowItem.modelData.kind === "sink")   return "󰓃";
                                    return rowItem.muted ? "󰖁" : "󰕾";
                                }
                                color: rowItem.muted ? Theme.red
                                       : rowItem.isDefault ? Theme.mauve
                                       : rowItem.sel ? Theme.mauve : Theme.subtext0
                                font.pixelSize: root.s(18)
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - root.s(24) - root.s(150) - root.s(46) - parent.spacing * 3
                                elide: Text.ElideRight
                                text: rowItem.isHeader ? "" : root.label(rowItem.modelData)
                                color: rowItem.sel ? Theme.rowSelectFg : Theme.text
                                font.pixelSize: root.s(15)
                            }

                            // Drag anywhere on the track to set the level.
                            Rectangle {
                                id: track
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.s(150)
                                height: root.s(6)
                                color: Theme.surface0
                                radius: Theme.borderRadius

                                Rectangle {
                                    width: track.width * Math.max(0, Math.min(1, rowItem.pct / 100))
                                    height: parent.height
                                    color: rowItem.muted ? Theme.red
                                           : rowItem.sel ? Theme.mauve : Theme.surface1
                                    radius: Theme.borderRadius
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -root.s(10)   // the track is 6px tall; the grab area shouldn't be
                                    onPressed: function (e) { root.selected = rowItem.index; set(e.x); }
                                    onPositionChanged: function (e) { if (pressed) set(e.x); }
                                    function set(x) {
                                        root.setVolume(rowItem.modelData, (x - root.s(10)) / track.width);
                                    }
                                }
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.s(46)
                                horizontalAlignment: Text.AlignRight
                                text: rowItem.isHeader ? "" : rowItem.pct + "%"
                                color: rowItem.muted ? Theme.red : Theme.subtext0
                                font.pixelSize: root.s(14)
                            }
                        }
                    }
                }
            }
        }
    }
}
