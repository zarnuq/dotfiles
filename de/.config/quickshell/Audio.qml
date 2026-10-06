pragma ComponentBehavior: Bound
import Quickshell.Services.Pipewire
import QtQuick

// The mixer: output devices, input devices, and a volume slider per playing
// app (Super+R A; replaced pulsemixer in a floating kitty). Picker supplies
// overlay, focus and IPC; this file is the list and the wiring.
Picker {
    id: root

    ipcTarget: "audio"

    // Nodes only publish `.audio` (and their properties) while something holds
    // a binding on them, and the menu has to be correct in the frame it opens —
    // so the tracker stays armed rather than being gated on `open`. It's ~16
    // nodes of bookkeeping, no polling.
    PwObjectTracker { objects: Pipewire.nodes.values }

    function prop(n, key) { return (n && n.properties) ? (n.properties[key] || "") : ""; }

    // media.class rather than isSink/isStream: a playback stream reports
    // isSink true as well (it feeds one), so the flags alone can't tell an
    // output device from an app playing to it.
    rows: {
        var all = Pipewire.nodes.values;
        var sinks = [], sources = [], streams = [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (!n.audio) continue;
            var c = root.prop(n, "media.class");
            if (c === "Audio/Sink") sinks.push(n);
            else if (c === "Audio/Source") sources.push(n);
            // The EQ filter-chains and the mic loopback are Stream/Output/Audio
            // too. They carry no application.name, which is exactly what
            // separates plumbing from something you'd actually want to turn down.
            else if (c === "Stream/Output/Audio" && root.prop(n, "application.name") !== "") streams.push(n);
        }

        var r = [];
        function section(title, nodes, kind): void {
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
        var n = row.node, media = root.prop(n, "media.name");
        if (row.kind === "stream")
            return root.prop(n, "application.name") + (media ? " — " + media : "");
        return Volume.nameOf(n);
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
    property real volWanted: 0
    property bool volDirty: false

    function levelOf(node) {
        if (!node || !node.audio) return 0;
        return node === root.volNode ? root.volWanted : node.audio.volume;
    }

    function setVolume(row, v): void {
        if (!row.node || !row.node.audio) return;
        root.volNode = row.node;
        root.volWanted = Math.max(0, Math.min(1, v));
        root.volDirty = true;
        if (!volFlush.running) root.writeVolume();
    }

    function writeVolume(): void {
        if (!root.volNode || !root.volNode.audio) return;
        volSettle.stop();
        root.volNode.audio.volume = root.volWanted;
        root.volDirty = false;
        volFlush.restart();
    }

    Timer {
        id: volFlush
        interval: 40
        onTriggered: {
            if (root.volDirty) root.writeVolume();
            else volSettle.restart();
        }
    }
    // Hand the row back to the graph once it has had time to echo the last
    // write; releasing immediately would snap the slider to the stale value.
    Timer {
        id: volSettle
        interval: 200
        onTriggered: root.volNode = null;
    }

    function nudge(i, delta): void {
        // Off the wanted level, not the echoed one, or held keys lose steps.
        if (selectable(i)) root.setVolume(rows[i], root.levelOf(rows[i].node) + delta);
    }
    function toggleMute(i): void {
        if (!selectable(i)) return;
        var n = rows[i].node;
        if (n && n.audio) n.audio.muted = !n.audio.muted;
    }

    function activate(i): void {
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
        Volume.useSink(row.node.name);
    }

    box: Component {
        PickerList {
            picker: root

            onExtraKey: function (e) {
                var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier));
                if (e.key === Qt.Key_M && plain) { root.toggleMute(root.selected); }
                else if (e.key === Qt.Key_Right || (e.key === Qt.Key_L && plain)) {
                    root.nudge(root.selected, 0.05);
                } else if (e.key === Qt.Key_Left || (e.key === Qt.Key_H && plain)) {
                    root.nudge(root.selected, -0.05);
                } else { return; }
                e.accepted = true;
            }

            rowDelegate: PickerRow {
                id: rowItem
                readonly property var audio: rowItem.isHeader ? null : rowItem.modelData.node.audio
                readonly property bool muted: rowItem.audio ? rowItem.audio.muted : false
                readonly property int pct: rowItem.audio ? Math.round(root.levelOf(rowItem.modelData.node) * 100) : 0
                // Only a sink or source can be either default.
                readonly property bool isDefault: !rowItem.isHeader
                    && (rowItem.modelData.node === Volume.sink || rowItem.modelData.node === Volume.source)

                picker: root
                width: parent.width
                current: rowItem.isDefault
                onActivated: root.activate(rowItem.index)

                icon: {
                    if (rowItem.isHeader) return "";
                    if (rowItem.modelData.kind === "source") return rowItem.muted ? "󰍭" : "󰍬";
                    if (rowItem.modelData.kind === "sink")   return "󰓃";
                    return rowItem.muted ? "󰖁" : "󰕾";
                }
                iconSize: root.s(18)
                iconColor: rowItem.muted ? Theme.red
                           : (rowItem.isDefault || rowItem.sel) ? Theme.mauve : Theme.subtext0

                label: rowItem.isHeader ? "" : root.label(rowItem.modelData)

                slotWidth: root.s(150)

                trailing: rowItem.isHeader ? "" : rowItem.pct + "%"
                trailingWidth: root.s(46)
                trailingSize: root.s(14)
                trailingColor: rowItem.muted ? Theme.red : Theme.subtext0

                // The slot's one control: drag anywhere on the track to set
                // the level. The row makes room for it; this fills that room.
                Gauge {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: root.s(6)
                    fraction: Math.max(0, Math.min(1, rowItem.pct / 100))
                    fillColor: rowItem.muted ? Theme.red
                               : rowItem.sel ? Theme.mauve : Theme.surface1

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -root.s(10)   // the track is 6px tall; the grab area shouldn't be
                        onPressed: function (e) { root.selected = rowItem.index; set(e.x); }
                        onPositionChanged: function (e) { if (pressed) set(e.x); }
                        function set(x): void {
                            root.setVolume(rowItem.modelData, (x - root.s(10)) / track.width);
                        }
                    }
                }
            }
        }
    }
}
