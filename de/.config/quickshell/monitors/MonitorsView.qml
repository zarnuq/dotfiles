import Quickshell
import QtQuick
import ".."

// The configurator's state and layout: layout bar on top, arrangement canvas in
// the middle, inspector for the selected head at the bottom.
//
// Everything goes through `scripts/monitors.py` — one `state` read on open, one
// `save`/`activate`/`delete` per action. The script owns the ZON and the symlink,
// so nothing here knows the file format.
//
// A "preset" is a FILE in ~/.config/reach/monitors/, and the active one is
// whatever `monitors.zon` links to. reach has no idea any of that is happening:
// it opens one path and applies what it finds.
FocusScope {
    id: root

    signal closeRequested()

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/monitors.py"

    // What is on disk.
    property var presets: []
    property string activeName: ""
    property var outputs: []        // wlr-randr: what is plugged in, with modes
    property string linkPath: ""
    property string presetDir: ""
    // The link names a layout whose file is gone. reach reads that as no file at
    // all, so it is worth saying out loud rather than showing an empty canvas.
    property bool activeMissing: false

    // The working copy the canvas edits: one entry per head, whether or not it is
    // in the preset (`included`) or plugged in (`connected`). Keeping the
    // unplugged ones editable is the point of a preset file — the desktop layout
    // has to be editable from the laptop.
    property var working: []
    property int selected: 0
    property string status: ""

    // Compared against the working copy to light the Apply button. A JSON compare
    // is exact and costs nothing at this size; tracking edits by hand would drift
    // the moment a control forgot to set the flag.
    property string savedState: ""
    readonly property bool dirty: savedState !== "" && savedState !== JSON.stringify(includedOnly())

    function s(n) { return Config.s(n); }

    // ---- geometry helpers ---------------------------------------------------
    // A rotated head's w/h are its MODE; the transform is what swaps them in the
    // layout. Every size question in the canvas goes through these two.
    function effW(m) { return isTurned(m) ? m.h : m.w; }
    function effH(m) { return isTurned(m) ? m.w : m.h; }
    function isTurned(m) {
        var t = m.transform || "normal";
        return t === "rotate_90" || t === "rotate_270"
            || t === "flipped_90" || t === "flipped_270";
    }

    /// The bounding box of `list` in layout pixels, or null when it is empty.
    /// The canvas fits its zoom to it, a save normalises against its top-left,
    /// and an unlisted head is parked past its right edge.
    function extent(list) {
        if (!list || list.length === 0) return null;
        var e = { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity };
        for (var i = 0; i < list.length; i++) {
            var m = list[i];
            e.minX = Math.min(e.minX, m.x);
            e.minY = Math.min(e.minY, m.y);
            e.maxX = Math.max(e.maxX, m.x + effW(m));
            e.maxY = Math.max(e.maxY, m.y + effH(m));
        }
        return e;
    }

    // ---- loading ------------------------------------------------------------

    function reload() {
        stateProc.refresh();
    }

    function applyState(data) {
        if (!data) {
            root.status = "monitors.py failed — is it executable?";
            return;
        }
        root.presets = data.presets || [];
        root.activeName = data.active || "";
        root.outputs = data.outputs || [];
        root.linkPath = data.link || "";
        root.presetDir = data.dir || "";
        root.activeMissing = !!data.activeMissing;
        root.loadPreset(root.activeName);
    }

    /// Build the working copy for `name` by merging the preset with the live
    /// outputs: preset entries first (order is monitor numbering, so it is
    /// meaningful), then any connected head the preset does not mention.
    function loadPreset(name) {
        var preset = null;
        for (var i = 0; i < root.presets.length; i++)
            if (root.presets[i].name === name) preset = root.presets[i];

        var out = [], seen = {};
        var monitors = preset ? (preset.monitors || []) : [];
        for (var j = 0; j < monitors.length; j++) {
            var m = monitors[j];
            seen[m.name] = true;
            out.push(root.entry(m, true));
        }
        // A head that is plugged in but not in the preset is parked to the RIGHT
        // of everything the preset places, not at 0,0 — dropped at the origin it
        // sits on top of the first monitor, and two overlapping rectangles is
        // exactly the picture this window exists to prevent.
        var box = root.extent(out);
        var park = box ? Math.max(0, box.maxX) : 0;

        for (var k = 0; k < root.outputs.length; k++) {
            var o = root.outputs[k];
            if (seen[o.name]) continue;
            var unlisted = root.entry({
                name: o.name,
                w: root.currentMode(o.name, "width"),
                h: root.currentMode(o.name, "height"),
                refresh: 0, x: park, y: 0, scale: 1.0, transform: "normal"
            }, false);
            park += root.effW(unlisted);
            out.push(unlisted);
        }
        root.working = out;
        root.selected = 0;
        root.savedState = JSON.stringify(root.includedOnly());
        root.status = preset ? ""
            : root.activeMissing ? "monitors.zon points at '" + name + "', which no longer exists"
            : (name ? "layout '" + name + "' not found" : "no layout selected");
    }

    function entry(m, included) {
        return {
            name: m.name,
            w: m.w || 0, h: m.h || 0, refresh: m.refresh || 0,
            x: m.x || 0, y: m.y || 0,
            scale: m.scale || 1.0,
            transform: m.transform || "normal",
            included: included,
            connected: root.outputFor(m.name) !== null
        };
    }

    function outputFor(name) {
        for (var i = 0; i < root.outputs.length; i++)
            if (root.outputs[i].name === name) return root.outputs[i];
        return null;
    }

    function currentMode(name, field) {
        var o = root.outputFor(name);
        if (!o || !o.modes) return 0;
        for (var i = 0; i < o.modes.length; i++)
            if (o.modes[i].current) return o.modes[i][field];
        return o.modes.length ? o.modes[0][field] : 0;
    }

    /// The modes a head offers, newest-first as wlr-randr gives them, deduped to
    /// one entry per w×h@refresh. A head that is not plugged in offers none, so
    /// its mode stays whatever the preset recorded.
    function modesFor(name) {
        var o = root.outputFor(name);
        if (!o || !o.modes) return [];
        var out = [], seen = {};
        for (var i = 0; i < o.modes.length; i++) {
            var m = o.modes[i];
            var hz = Math.round(m.refresh * 1000);
            var key = m.width + "x" + m.height + "@" + hz;
            if (seen[key]) continue;
            seen[key] = true;
            out.push({ w: m.width, h: m.height, refresh: hz, label: m.width + "×" + m.height + " " + Math.round(m.refresh) + "Hz" });
        }
        return out;
    }

    // ---- editing ------------------------------------------------------------
    // Every mutation assigns a NEW array: QML only notifies on assignment, so
    // mutating in place would leave the canvas drawing the old positions.

    function patch(index, fields) {
        var next = root.working.slice();
        var m = {};
        for (var k in next[index]) m[k] = next[index][k];
        for (var f in fields) m[f] = fields[f];
        next[index] = m;
        root.working = next;
    }

    function move(index, x, y) { root.patch(index, { x: Math.round(x), y: Math.round(y) }); }

    function cycleTransform(index) {
        var order = ["normal", "rotate_90", "rotate_180", "rotate_270"];
        var at = order.indexOf(root.working[index].transform);
        root.patch(index, { transform: order[(at + 1) % order.length] });
    }

    function stepMode(index, direction) {
        var m = root.working[index];
        var modes = root.modesFor(m.name);
        if (modes.length === 0) return;
        var at = -1;
        for (var i = 0; i < modes.length; i++)
            if (modes[i].w === m.w && modes[i].h === m.h
                && (m.refresh === 0 || modes[i].refresh === m.refresh)) at = i;
        var next = (at < 0) ? 0 : (at + direction + modes.length) % modes.length;
        root.patch(index, { w: modes[next].w, h: modes[next].h, refresh: modes[next].refresh });
    }

    function stepScale(index, direction) {
        var steps = [1.0, 1.25, 1.5, 1.75, 2.0];
        var m = root.working[index];
        var at = steps.indexOf(m.scale);
        if (at < 0) at = 0;
        var next = Math.max(0, Math.min(steps.length - 1, at + direction));
        root.patch(index, { scale: steps[next] });
    }

    function toggleIncluded(index) {
        var m = root.working[index];
        if (m.included && root.includedOnly().length <= 1) {
            root.status = "a preset needs at least one output";
            return;
        }
        root.patch(index, { included: !m.included });
    }

    /// What gets written: the included heads, shifted so the top-left of the
    /// arrangement sits at 0,0. Normalising here rather than preserving negative
    /// coordinates keeps the saved file looking like one a human would write, and
    /// the layout is identical either way — only the origin moves.
    function includedOnly() {
        var mons = [];
        for (var i = 0; i < root.working.length; i++)
            if (root.working[i].included) mons.push(root.working[i]);
        if (mons.length === 0) return [];

        var box = root.extent(mons);
        var out = [];
        for (var k = 0; k < mons.length; k++) {
            var m = mons[k];
            var one = { name: m.name, w: m.w, h: m.h, x: m.x - box.minX, y: m.y - box.minY };
            if (m.refresh) one.refresh = m.refresh;
            if (m.scale && m.scale !== 1.0) one.scale = m.scale;
            if (m.transform && m.transform !== "normal") one.transform = m.transform;
            out.push(one);
        }
        return out;
    }

    // ---- commands -----------------------------------------------------------

    function run(args, note) {
        root.status = note;
        runProc.command = [root.script].concat(args);
        runProc.refresh();
    }

    function save(name) {
        var mons = root.includedOnly();
        if (mons.length === 0) { root.status = "nothing to save"; return; }
        root.run(["save", name, JSON.stringify({ monitors: mons })], "saving " + name + "…");
    }

    function activate(name) {
        if (root.dirty) { root.status = "unsaved changes — apply or revert first"; return; }
        root.run(["activate", name], "switching to " + name + "…");
    }

    function removePreset(name) { root.run(["delete", name], "deleting " + name + "…"); }

    /// Switching is re-pointing the symlink, so an unsaved canvas would be
    /// silently abandoned — say so instead. Clicking the ACTIVE one re-reads it,
    /// which is the natural "revert" gesture.
    function pick(name) {
        if (name === root.activeName) root.loadPreset(name);
        else root.activate(name);
    }

    // Both are one-shot: `running: false` parks Poll's timer, so a run happens
    // only on refresh(). What Poll is borrowed for is the Process + collector +
    // JSON.parse plumbing, which `onJsonData` hands over as a value or null.
    Poll {
        id: stateProc
        running: false
        command: [root.script, "state"]
        onJsonData: value => root.applyState(value)
    }

    Poll {
        id: runProc
        running: false
        onJsonData: reply => {
            if (!reply) root.status = "no reply from monitors.py";
            else if (!reply.ok) root.status = reply.error || "failed";
            else root.status = reply.reloaded === false ? "saved (reach not running)" : "applied";
            // Re-read rather than patching the local copy: the script is the
            // authority on what landed in the file, including a rename or a
            // refusal that left it unchanged.
            stateProc.refresh();
        }
    }

    // ---- layout -------------------------------------------------------------

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.closeRequested(); event.accepted = true; }
        else if (event.key === Qt.Key_R && root.working.length) { root.cycleTransform(root.selected); event.accepted = true; }
        else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) { root.save(root.activeName); event.accepted = true; }
        else if (event.key === Qt.Key_Tab && root.working.length) {
            root.selected = (root.selected + 1) % root.working.length;
            event.accepted = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: root.s(16)
        spacing: root.s(12)

        // --- preset bar ---
        Row {
            id: presetBar
            width: parent.width
            spacing: root.s(8)

            Txt {
                text: "Layouts"
                color: Theme.subtext0
                font.pixelSize: root.s(13)
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: root.presets
                Rectangle {
                    required property var modelData
                    readonly property bool isActive: modelData.name === root.activeName
                    width: label.implicitWidth + root.s(22)
                    height: root.s(30)
                    color: isActive ? Theme.mauve : (hover.hovered ? Theme.surface1 : Theme.surface0)
                    Txt {
                        id: label
                        anchors.centerIn: parent
                        text: parent.modelData.name
                        color: parent.isActive ? Theme.crust : Theme.text
                        font.pixelSize: root.s(13)
                    }
                    HoverHandler { id: hover }
                    TapHandler { onTapped: root.pick(parent.modelData.name) }

                    // Delete, on hover, and never on the active layout: removing
                    // it would leave monitors.zon dangling. The script refuses
                    // that too — this just doesn't offer it.
                    Txt {
                        anchors.right: parent.right
                        anchors.rightMargin: root.s(4)
                        anchors.top: parent.top
                        text: "×"
                        visible: hover.hovered && !parent.isActive
                        color: Theme.red
                        font.pixelSize: root.s(12)
                        TapHandler { onTapped: root.removePreset(parent.parent.modelData.name) }
                    }
                }
            }

            // Save-as: a name field rather than a second command path, because
            // "save under a new name" and "rename this layout" are the same act.
            Rectangle {
                width: root.s(150)
                height: root.s(30)
                color: Theme.surface0
                border.width: 1
                border.color: newName.activeFocus ? Theme.mauve : Theme.surface1
                Field {
                    id: newName
                    anchors.fill: parent
                    anchors.leftMargin: root.s(8)
                    font.pixelSize: root.s(13)
                    selectByMouse: true
                    onAccepted: if (text.length) { root.save(text); text = ""; }
                    Txt {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !newName.text.length && !newName.activeFocus
                        text: "save as…"
                        color: Theme.overlay0
                        font.pixelSize: root.s(13)
                    }
                }
            }
        }

        // --- arrangement ---
        MonitorCanvas {
            view: root
            width: parent.width
            height: parent.height - presetBar.height - inspector.height - footer.height - root.s(36)
        }

        // --- selected head ---
        MonitorInspector {
            id: inspector
            view: root
            width: parent.width
        }

        // --- footer ---
        Item {
            id: footer
            width: parent.width
            height: root.s(34)

            Txt {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - root.s(260)
                elide: Text.ElideRight
                text: root.status !== "" ? root.status
                    : root.activeName !== "" ? root.linkPath + " → monitors/" + root.activeName + ".zon"
                    : root.linkPath + " (no layout linked yet)"
                color: root.status !== "" ? Theme.text : Theme.overlay0
                font.pixelSize: root.s(12)
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.s(8)

                MonitorButton {
                    label: "Revert"
                    enabled: root.dirty
                    onClicked: root.loadPreset(root.activeName)
                }
                MonitorButton {
                    label: "Apply"
                    accent: true
                    enabled: root.dirty && root.activeName !== ""
                    onClicked: root.save(root.activeName)
                }
            }
        }
    }
}
