pragma ComponentBehavior: Bound
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
    signal identifyRequested()

    // The owning Scope (Monitors.qml) — it holds the mirror Process, which must
    // outlive this window.
    property var scope: null

    // The names of the heads currently plugged in — the mirror dropdown's choices
    // (you can't clone onto a head that is not there).
    readonly property var connected: (root.outputs || []).map(o => o.name)

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/monitors.py"

    // What is on disk.
    property var presets: []
    property string activeName: ""
    property var outputs: []        // wlr-randr: what is plugged in, with modes
    property string linkPath: ""
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

    // A layout being built from scratch (New) has nothing saved to diff against,
    // so `dirty` can't light Apply — `isNew` does. Apply is offered whenever there
    // is something to write and it either differs from disk or is brand new.
    property bool isNew: false
    property bool naming: false
    // The layout currently LOADED in the canvas. Picking a layout only loads it
    // here (no live switch) — Apply is what re-points the symlink. So Apply is
    // offered when there is something to write and it differs from disk: edited,
    // brand new, or a different layout than the one currently live.
    property string loaded: ""
    readonly property bool canApply: includedOnly().length > 0 && (dirty || isNew || loaded !== activeName)

    // ---- geometry helpers ---------------------------------------------------
    // A rotated head's w/h are its MODE; the transform is what swaps them in the
    // layout. Every size question in the canvas goes through these two.
    function effW(m) { return isTurned(m) ? m.h : m.w; }
    function effH(m) { return isTurned(m) ? m.w : m.h; }
    function isTurned(m) { return /_(90|270)$/.test(m.transform); }

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

    function reload(): void {
        stateProc.refresh();
    }

    function applyState(data): void {
        if (!data) {
            root.status = "monitors.py failed — is it executable?";
            return;
        }
        root.presets = data.presets || [];
        root.activeName = data.active || "";
        root.outputs = data.outputs || [];
        root.linkPath = data.link || "";
        root.activeMissing = !!data.activeMissing;
        root.loadPreset(root.activeName);
    }

    /// Build the working copy for `name` by merging the preset with the live
    /// outputs: preset entries first (order is monitor numbering, so it is
    /// meaningful), then any connected head the preset does not mention.
    function loadPreset(name): void {
        var preset = root.presets.find(p => p.name === name) || null;
        var out = (preset && preset.monitors || []).map(m => root.entry(m, true));
        // A head that is plugged in but not in the preset is parked to the RIGHT
        // of everything the preset places, not at 0,0 — dropped at the origin it
        // sits on top of the first monitor, and two overlapping rectangles is
        // exactly the picture this window exists to prevent.
        var box = root.extent(out);
        var park = box ? Math.max(0, box.maxX) : 0;

        for (var k = 0; k < root.outputs.length; k++) {
            var o = root.outputs[k];
            if (out.some(m => m.name === o.name)) continue;
            var modes = o.modes || [];
            var mode = modes.find(m => m.current) || modes[0] || { width: 0, height: 0 };
            var unlisted = root.entry({ name: o.name, w: mode.width, h: mode.height, x: park }, false);
            park += root.effW(unlisted);
            out.push(unlisted);
        }
        root.working = out;
        root.selected = 0;
        root.isNew = false;
        root.loaded = name;
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

    function outputFor(name) { return root.outputs.find(o => o.name === name) || null; }

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

    function patch(index, fields): void {
        var next = root.working.slice();
        next[index] = Object.assign({}, next[index], fields);
        root.working = next;
    }

    function move(index, x, y): void { root.patch(index, { x: Math.round(x), y: Math.round(y) }); }

    function cycleTransform(index): void {
        var order = ["normal", "rotate_90", "rotate_180", "rotate_270"];
        var at = order.indexOf(root.working[index].transform);
        root.patch(index, { transform: order[(at + 1) % order.length] });
    }

    function stepMode(index, direction): void {
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

    function stepScale(index, direction): void {
        var steps = [1.0, 1.25, 1.5, 1.75, 2.0];
        var m = root.working[index];
        var at = steps.indexOf(m.scale);
        if (at < 0) at = 0;
        var next = Math.max(0, Math.min(steps.length - 1, at + direction));
        root.patch(index, { scale: steps[next] });
    }

    function toggleIncluded(index): void {
        var m = root.working[index];
        if (m.included && root.includedOnly().length <= 1) {
            root.status = "a preset needs at least one output";
            return;
        }
        root.patch(index, { included: !m.included });
    }

    /// Remove (Delete / the inspector button): a head that is plugged in only
    /// leaves the layout (toggleIncluded — it can be re-added, so keep drawing it),
    /// but a head that is NOT connected has no reason to stay on the canvas at all,
    /// so it is dropped from the working copy. A save then omits it for good.
    function removeOrToggle(index): void {
        var m = root.working[index];
        if (m.connected) { root.toggleIncluded(index); return; }
        if (m.included && root.includedOnly().length <= 1) {
            root.status = "a preset needs at least one output";
            return;
        }
        var next = root.working.slice();
        next.splice(index, 1);
        root.working = next;
        if (root.selected >= next.length) root.selected = Math.max(0, next.length - 1);
    }

    /// What gets written: the included heads, shifted so the top-left of the
    /// arrangement sits at 0,0. Normalising here rather than preserving negative
    /// coordinates keeps the saved file looking like one a human would write, and
    /// the layout is identical either way — only the origin moves.
    function includedOnly() {
        var mons = root.working.filter(m => m.included);
        var box = root.extent(mons);
        return mons.map(m => {
            var one = { name: m.name, w: m.w, h: m.h, x: m.x - box.minX, y: m.y - box.minY };
            if (m.refresh) one.refresh = m.refresh;
            if (m.scale && m.scale !== 1.0) one.scale = m.scale;
            if (m.transform && m.transform !== "normal") one.transform = m.transform;
            return one;
        });
    }

    /// A blank layout: every connected output, included, laid left-to-right. No
    /// file is touched until Apply names it — this only swaps the working copy.
    function newLayout(): void {
        var x = 0, out = [];
        for (var k = 0; k < root.outputs.length; k++) {
            var o = root.outputs[k];
            var modes = o.modes || [];
            var mode = modes.find(m => m.current) || modes[0] || { width: 0, height: 0 };
            var e = root.entry({ name: o.name, w: mode.width, h: mode.height, x: x }, true);
            x += root.effW(e);
            out.push(e);
        }
        root.working = out;
        root.selected = 0;
        root.isNew = true;
        root.loaded = "";
        root.savedState = "";
        root.status = out.length ? "new layout — arrange, then Apply to name it"
                                 : "no outputs connected";
    }

    // ---- commands -----------------------------------------------------------

    /// Apply opens an inline name prompt rather than writing straight away: a
    /// layout is a named file, and the name is the one thing the canvas can't
    /// supply. Pre-filled with the active name so re-applying an edit is just Enter.
    function startNaming(): void {
        if (root.includedOnly().length === 0) { root.status = "nothing to save"; return; }
        nameField.text = root.isNew ? "" : root.loaded;
        root.naming = true;
        nameField.forceActiveFocus();
        nameField.selectAll();
    }

    function applyName(name): void {
        root.naming = false;
        root.save(name);
    }

    function run(args, note): void {
        root.status = note;
        runProc.command = [root.script].concat(args);
        runProc.refresh();
    }

    function save(name): void {
        var mons = root.includedOnly();
        if (mons.length === 0) { root.status = "nothing to save"; return; }
        root.run(["save", name, JSON.stringify({ monitors: mons })], "saving " + name + "…");
    }

    function activate(name): void {
        if (root.dirty) { root.status = "unsaved changes — apply or revert first"; return; }
        root.run(["activate", name], "switching to " + name + "…");
    }

    function removePreset(name): void { root.run(["delete", name], "deleting " + name + "…"); }

    /// Picking a layout only LOADS it into the canvas to view/edit — it does not
    /// switch the live output. Apply is what re-points the symlink. Unsaved edits
    /// would be lost by loading another, so refuse until applied or reverted.
    function pick(name): void {
        if (name === root.loaded) return;
        if (root.dirty) { root.status = "unsaved changes — Apply or Revert first"; return; }
        root.loadPreset(name);
    }

    /// Apply: save edits (prompting for a name) if the canvas was changed or is a
    /// new layout, otherwise just switch the live output to the loaded layout.
    function apply(): void {
        if (root.dirty || root.isNew) root.startNaming();
        else root.activate(root.loaded);
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
        else if (event.key === Qt.Key_I) { root.identifyRequested(); event.accepted = true; }
        else if (event.key === Qt.Key_R && root.working.length) { root.cycleTransform(root.selected); event.accepted = true; }
        else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && root.working.length) { root.removeOrToggle(root.selected); event.accepted = true; }
        else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) { root.startNaming(); event.accepted = true; }
        else if (event.key === Qt.Key_Tab && root.working.length) {
            root.selected = (root.selected + 1) % root.working.length;
            event.accepted = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Config.s(16)
        spacing: Config.s(12)

        // --- preset bar ---
        Row {
            id: presetBar
            width: parent.width
            spacing: Config.s(8)

            Txt {
                text: "Layouts"
                color: Theme.subtext0
                font.pixelSize: Config.s(13)
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: root.presets
                MonitorButton {
                    id: layoutBtn
                    required property var modelData
                    // Mauve accent = the layout loaded in the canvas (selected).
                    // The live one (the symlink target) gets a teal dot when it is
                    // not the one you are looking at — Apply is what makes the
                    // selected layout live.
                    readonly property bool isSelected: layoutBtn.modelData.name === root.loaded && !root.isNew
                    readonly property bool isLive: layoutBtn.modelData.name === root.activeName
                    label: layoutBtn.modelData.name + (layoutBtn.isSelected && root.dirty ? " *" : "")
                    accent: layoutBtn.isSelected
                    accentHover: false
                    hPad: Config.s(22)
                    // Click only LOADS the layout into the canvas; Apply switches.
                    // Deleting a layout lives on the inspector's "Remove layout"
                    // button, so a chip can't be trashed by a stray click.
                    onClicked: root.pick(layoutBtn.modelData.name)

                    // Live marker: a teal dot, only when live ≠ selected.
                    Rectangle {
                        width: Config.s(6); height: width; radius: width / 2
                        color: Theme.teal
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Config.s(4)
                        visible: layoutBtn.isLive && !layoutBtn.isSelected
                    }
                }
            }

            MonitorButton {
                label: "+ New"
                onClicked: root.newLayout()
            }

            // Shown only while a brand-new layout is being arranged: nothing on
            // disk is current, so the layout chips go dim and this marks where you
            // are. Clicking it opens the name prompt (same as Apply).
            MonitorButton {
                label: "unsaved — Apply to name"
                accent: true
                visible: root.isNew
                onClicked: root.startNaming()
            }
        }

        // --- arrangement ---
        MonitorCanvas {
            view: root
            width: parent.width
            height: parent.height - presetBar.height - inspector.height - footer.height - Config.s(36)
        }

        // --- selected head ---
        MonitorInspector {
            id: inspector
            view: root
            width: parent.width
        }

        // --- footer ---
        // --- footer: the path/status line, then one merged action row ---
        Column {
            id: footer
            width: parent.width
            spacing: Config.s(8)

            Txt {
                width: parent.width
                elide: Text.ElideRight
                visible: !root.naming
                text: root.status !== "" ? root.status
                    : root.activeName !== "" ? root.linkPath + " → monitors/" + root.activeName + ".zon"
                    : root.linkPath + " (no layout linked yet)"
                color: root.status !== "" ? Theme.text : Theme.overlay0
                font.pixelSize: Config.s(12)
            }

            Item {
                width: parent.width
                height: Config.s(34)

                // Left: destructive actions, kept apart from Apply on the right.
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.s(8)
                    visible: !root.naming

                    MonitorButton {
                        readonly property var sel: root.working[root.selected] || null
                        label: sel && sel.included ? "Remove monitor" : "Add monitor"
                        enabled: root.working.length > 0
                        onClicked: root.removeOrToggle(root.selected)
                    }
                    // Two-step so a layout file can't be trashed by accident.
                    MonitorButton {
                        id: rmLayout
                        property bool confirming: false
                        Timer { id: rmTimer; interval: 2500; onTriggered: rmLayout.confirming = false }
                        label: rmLayout.confirming ? "Delete '" + root.activeName + "' — confirm" : "Remove layout"
                        accent: rmLayout.confirming
                        enabled: root.activeName !== ""
                        onClicked: {
                            if (rmLayout.confirming) { rmLayout.confirming = false; root.removePreset(root.activeName); }
                            else { rmLayout.confirming = true; rmTimer.restart(); }
                        }
                    }
                }

                // Right: view/apply actions.
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.s(8)
                    visible: !root.naming

                    MonitorButton {
                        label: "Identify"
                        onClicked: root.identifyRequested()
                    }
                    MonitorButton {
                        label: "Revert"
                        enabled: root.dirty
                        onClicked: root.loadPreset(root.loaded)
                    }
                    MonitorButton {
                        label: "Apply"
                        accent: true
                        enabled: root.canApply
                        onClicked: root.apply()
                    }
                }

            // Name prompt, shown in place of the action row while Apply is pending.
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Config.s(8)
                visible: root.naming

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Layout name:"
                    color: Theme.subtext0
                    font.pixelSize: Config.s(13)
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Config.s(180)
                    height: Config.s(30)
                    color: Theme.surface0
                    border.width: 1
                    border.color: nameField.activeFocus ? Theme.mauve : Theme.surface1
                    Field {
                        id: nameField
                        anchors.fill: parent
                        anchors.leftMargin: Config.s(8)
                        font.pixelSize: Config.s(13)
                        selectByMouse: true
                        onAccepted: if (text.length) root.applyName(text)
                        Keys.onEscapePressed: root.naming = false
                    }
                }
                MonitorButton {
                    label: "Save"
                    accent: true
                    enabled: nameField.text.length > 0
                    onClicked: root.applyName(nameField.text)
                }
                MonitorButton {
                    label: "Cancel"
                    onClicked: root.naming = false
                }
            }
            }
        }
    }
}
