pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

// Screenshot menu. `qs ipc call screenshot open`, or ">" → Screenshot in the
// launcher.
//
// What it is for: the `Super+S` chord names outputs LITERALLY (0→eDP-1,
// 1→DP-1, 2→DP-2, 3→DP-3), which is a desktop list on the desktop and a laptop
// list nowhere — `0` is dead here, `1`/`2` are dead on the laptop. The rows
// below come from `Quickshell.screens`, so there is no output name in this file
// or in the script, and each machine lists exactly the heads it has.
//
// screenshot.sh still owns where a file goes and what annotates it, the way
// wallpaper-thumbs owns the thumbnail naming rule: this is a menu, not a second
// opinion about ~/Pictures.
Picker {
    id: root

    ipcTarget: "screenshot"

    readonly property int footerHeight: s(30)
    readonly property string script: Quickshell.env("HOME") + "/.local/bin/screenshot.sh"

    boxWidth: s(460)
    barHeight: footerHeight

    // Applies to whole-output captures only, which is the case it exists for:
    // photographing a menu that a full-screen picker would have dismissed.
    // A delay on a region capture would only postpone slurp's crosshair, which
    // is not what anybody means by it.
    property bool delayed: false
    readonly property int delaySeconds: 3

    rows: {
        var r = [{ kind: "header", label: "Region" },
                 { kind: "act", label: "Copy to clipboard", hint: "→ wl-copy",    glyph: "󰆏", arg: "ss",      note: "Copied" },
                 { kind: "act", label: "Save and edit",     hint: "→ satty",      glyph: "󰏬", arg: "section", note: "Saved" },
                 { kind: "act", label: "Save",              hint: "→ ~/Pictures", glyph: "󰆓", arg: "region",  note: "Saved" },
                 { kind: "header", label: "Whole output" }];

        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            var sc = screens[i];
            // These are the sizes as laid out, so a rotated head reads
            // 1080×1920 rather than its 1920×1080 mode — which is the number
            // that describes the image you are about to get.
            r.push({ kind: "out", label: sc.name, hint: sc.width + "×" + sc.height,
                     glyph: "󰍹", arg: sc.name, note: "Saved" });
        }
        return r;
    }

    // ── firing ───────────────────────────────────────────────────────────
    // The picker is a full-screen overlay on EVERY output, so it is IN the
    // shot. Hiding is not enough by itself: a Wayland client can ask for its
    // surface to go away but cannot observe the compositor repainting without
    // it, so there is no event to wait on and a timer is the honest answer.
    // 200ms clears a frame at any refresh rate here. This matters more than
    // the launcher's hide-before-dispatch — there the mistake lasts a frame,
    // here it is written into the PNG.
    readonly property int unmapDelay: 200

    property var pendingRow: null

    function activate(i): void {
        if (!selectable(i)) return;
        var row = root.rows[i];
        root.pendingRow = row;
        shot.interval = root.unmapDelay
                        + (root.delayed && row.kind === "out" ? root.delaySeconds * 1000 : 0);
        root.hide();
        shot.restart();
    }

    /// POSIX single-quoting, since a row's argument reaches a shell.
    function sq(v) { return "'" + String(v).replace(/'/g, "'\\''") + "'"; }

    Timer {
        id: shot
        onTriggered: {
            var row = root.pendingRow;
            root.pendingRow = null;
            if (!row) return;
            // The `&&` is the point: screenshot.sh now fails when the capture
            // fails, so a cancelled selection says nothing instead of claiming
            // a save. Composed here rather than moved into the script, because
            // the Super+S chord appends its own notify-send and would then
            // fire two.
            Quickshell.execDetached(["sh", "-c",
                root.sq(root.script) + " " + root.sq(row.arg)
                + " && notify-send Screenshot " + root.sq(row.note + "!")]);
        }
    }

    box: Component {
        Item {
            id: content
            focus: true

            function reset(): void { root.delayed = false; }

            Keys.onPressed: function (e) {
                if (root.navKey(e)) return;
                if (e.key !== Qt.Key_D) return;
                root.delayed = !root.delayed;       // `d` is this menu's extra key
                e.accepted = true;
            }

            Column {
                anchors.fill: parent
                anchors.topMargin: root.s(12)
                spacing: 0

                Repeater {
                    model: root.rows

                    PickerRow {
                        id: rowItem
                        picker: root
                        width: content.width
                        headerHeight: root.headerHeight
                        rowHeight: root.rowHeight
                        onActivated: root.activate(rowItem.index)

                        Item {
                            visible: !rowItem.isHeader
                            anchors.fill: parent
                            anchors.leftMargin: root.s(18)
                            anchors.rightMargin: root.s(18)

                            Txt {
                                id: glyph
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.s(22)
                                text: rowItem.isHeader ? "" : rowItem.modelData.glyph
                                color: Theme.mauve
                                font.pixelSize: root.s(15)
                            }

                            Txt {
                                anchors.left: glyph.right
                                anchors.leftMargin: root.s(10)
                                anchors.verticalCenter: parent.verticalCenter
                                text: rowItem.isHeader ? "" : rowItem.modelData.label
                                color: rowItem.sel ? Theme.rowSelectFg : Theme.text
                                font.pixelSize: root.s(15)
                            }

                            Txt {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: rowItem.isHeader ? ""
                                      : (root.delayed && rowItem.modelData.kind === "out"
                                         ? root.delaySeconds + "s · " + rowItem.modelData.hint
                                         : rowItem.modelData.hint)
                                color: root.delayed && !rowItem.isHeader && rowItem.modelData.kind === "out"
                                       ? Theme.peach : Theme.overlay0
                                font.pixelSize: root.s(13)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: root.footerHeight

                    Txt {
                        anchors.centerIn: parent
                        text: root.delayed
                              ? "d · " + root.delaySeconds + "s delay on output captures"
                              : "d · delay an output capture"
                        color: root.delayed ? Theme.peach : Theme.surface1
                        font.pixelSize: root.s(11)
                    }
                }
            }
        }
    }
}
