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
    allScreens: false

    readonly property real scale: Config.onLaptop ? 0.85 : 1.0
    function s(n) { return Math.round(n * scale); }

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
    readonly property var rows: {
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

    readonly property int headerHeight: s(28)
    readonly property int rowHeight: s(40)
    boxWidth: s(560)
    boxHeight: {
        var h = s(12) * 2;
        for (var i = 0; i < rows.length; i++)
            h += rows[i].kind === "header" ? headerHeight : rowHeight;
        return Math.max(h, s(120));
    }

    property int selected: 0

    function selectable(i) { return i >= 0 && i < rows.length && rows[i].kind !== "header"; }

    // Headers aren't stops on the way down the list; step over them.
    function move(delta) {
        var i = selected + delta;
        while (i >= 0 && i < rows.length && rows[i].kind === "header") i += delta;
        if (selectable(i)) selected = i;
    }
    function firstSelectable() {
        for (var i = 0; i < rows.length; i++) if (rows[i].kind !== "header") return i;
        return 0;
    }

    function setVolume(row, v) {
        if (!row.node || !row.node.audio) return;
        row.node.audio.volume = Math.max(0, Math.min(1, v));
    }
    function nudge(i, delta) {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.node && row.node.audio) root.setVolume(row, row.node.audio.volume + delta);
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

            function reset() { root.selected = root.firstSelectable(); content.forceActiveFocus(); }

            Keys.onPressed: function (e) {
                var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier));
                if (e.key === Qt.Key_Escape) { root.hide(); }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.activate(root.selected); }
                else if (e.key === Qt.Key_M && plain) { root.toggleMute(root.selected); }
                else if (e.key === Qt.Key_Down || (e.key === Qt.Key_J && (plain || (e.modifiers & Qt.ControlModifier)))) {
                    root.move(1);
                } else if (e.key === Qt.Key_Up || (e.key === Qt.Key_K && (plain || (e.modifiers & Qt.ControlModifier)))) {
                    root.move(-1);
                } else if (e.key === Qt.Key_Right || (e.key === Qt.Key_L && plain)) {
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

                    Item {
                        id: rowItem
                        required property var modelData
                        required property int index
                        readonly property bool isHeader: modelData.kind === "header"
                        readonly property var audio: isHeader ? null : modelData.node.audio
                        readonly property bool muted: audio ? audio.muted : false
                        readonly property int pct: audio ? Math.round(audio.volume * 100) : 0
                        readonly property bool sel: index === root.selected
                        readonly property bool isDefault: !isHeader && root.isDefault(modelData)

                        width: content.width
                        height: isHeader ? root.headerHeight : root.rowHeight

                        // The default sink/source keeps a mauve wash of its own,
                        // so which device is live stays readable even while the
                        // cursor sits on some other row. Selection is a flat dark
                        // band; on the default row the two combine into a brighter
                        // wash rather than the selection hiding it.
                        Rectangle {
                            anchors.fill: parent
                            visible: rowItem.sel || rowItem.isDefault
                            color: rowItem.isDefault
                                   ? Qt.rgba(Theme.mauve.r, Theme.mauve.g, Theme.mauve.b, rowItem.sel ? 0.22 : 0.12)
                                   : "#11111b"
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: rowItem.isDefault
                            width: root.s(3)
                            height: parent.height
                            color: Theme.mauve
                        }

                        // Section label.
                        Txt {
                            visible: rowItem.isHeader
                            anchors.left: parent.left
                            anchors.leftMargin: root.s(18)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: root.s(4)
                            text: rowItem.isHeader ? rowItem.modelData.label : ""
                            color: Theme.surface1
                            font.pixelSize: root.s(13)
                        }

                        // The rows don't scroll, so hover can't fight the
                        // keyboard here — but the menu still maps under wherever
                        // the cursor already is, and Return on a preselected
                        // device row would switch the default sink unasked.
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            visible: !rowItem.isHeader
                            hoverEnabled: true
                            onPositionChanged: function (e) { if (root.hoverMoved(hover, e)) root.selected = rowItem.index; }
                            onClicked: { root.selected = rowItem.index; root.activate(rowItem.index); }
                        }

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
                                       : (!rowItem.isHeader && root.isDefault(rowItem.modelData)) ? Theme.mauve
                                       : rowItem.sel ? Theme.mauve : Theme.subtext0
                                font.pixelSize: root.s(18)
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - root.s(24) - root.s(150) - root.s(46) - parent.spacing * 3
                                elide: Text.ElideRight
                                text: rowItem.isHeader ? "" : root.label(rowItem.modelData)
                                color: rowItem.sel ? "#bac2de" : Theme.text
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
