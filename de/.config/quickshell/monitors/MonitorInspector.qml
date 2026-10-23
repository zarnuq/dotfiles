pragma ComponentBehavior: Bound
import QtQuick
import ".."

// The selected head's settings as click-to-open dropdown menus (replaced the
// ◀ value ▶ steppers, whose arrows were a few px wide, hard to hit, and — for
// rotation — did the same thing on both sides). Two rows: the settings on top,
// the two destructive actions below, well apart from the pickers.
//
// Menus open UPWARD (into the canvas above) so a long mode list never falls off
// the bottom of the window; `root.openMenu` keeps at most one open at a time.
Item {
    id: root

    required property var view
    readonly property int index: root.view.selected
    readonly property var mon: root.view.working[root.index] || null
    readonly property var modes: root.mon ? root.view.modesFor(root.mon.name) : []

    // Which dropdown is open ("" = none). Changing the selected head closes it.
    property string openMenu: ""
    onIndexChanged: root.openMenu = ""

    // One settings row (caption + 28px field) plus the top/bottom margins; the
    // Remove/Add and Remove-layout buttons moved down to the footer action line.
    implicitHeight: Config.s(78)

    // No panel fill — the inspector shares the window's base background like the
    // canvas and footer; only a hairline separates it from the canvas above.
    Rectangle {
        width: parent.width
        height: 1
        anchors.top: parent.top
        color: Theme.surface1
    }

    Column {
        anchors.fill: parent
        anchors.topMargin: Config.s(14)
        anchors.bottomMargin: Config.s(12)
        anchors.leftMargin: Config.s(12)
        anchors.rightMargin: Config.s(12)
        spacing: Config.s(12)

        // --- settings row ---
        Row {
            width: parent.width
            spacing: Config.s(16)

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Config.s(140)
                spacing: Config.s(2)
                Txt {
                    text: root.mon ? root.mon.name : "no output"
                    color: Theme.text
                    font.pixelSize: Config.s(15)
                }
                Txt {
                    text: !root.mon ? ""
                        : !root.mon.included ? "not in layout"
                        : !root.mon.connected ? "not connected" : "in layout"
                    color: root.mon && root.mon.connected && root.mon.included ? Theme.overlay0 : Theme.peach
                    font.pixelSize: Config.s(11)
                }
            }

            // Mode. An unplugged head offers no mode list, so its recorded mode is
            // shown and left alone (disabled) rather than reset to this machine's.
            Dropdown {
                menuKey: "mode"
                caption: "Mode"
                fieldWidth: Config.s(165)
                enabled: root.mon && root.modes.length > 0
                valueText: !root.mon ? "—"
                    : (root.mon.w ? root.mon.w + "×" + root.mon.h : "preferred")
                      + (root.mon.refresh ? "  " + Math.round(root.mon.refresh / 1000) + "Hz" : "")
                options: root.modes.map(m => ({ text: m.label, value: m }))
                onPicked: v => root.view.patch(root.index, { w: v.w, h: v.h, refresh: v.refresh })
            }

            Dropdown {
                menuKey: "scale"
                caption: "Scale"
                fieldWidth: Config.s(90)
                enabled: !!root.mon
                valueText: root.mon ? root.mon.scale.toFixed(2) : "—"
                options: [1.0, 1.25, 1.5, 1.75, 2.0].map(s => ({ text: s.toFixed(2), value: s }))
                onPicked: v => root.view.patch(root.index, { scale: v })
            }

            Dropdown {
                menuKey: "rotation"
                caption: "Rotation"
                fieldWidth: Config.s(110)
                enabled: !!root.mon
                valueText: !root.mon ? "—" : ({
                    "normal": "0°", "rotate_90": "90°", "rotate_180": "180°", "rotate_270": "270°",
                    "flipped": "flip", "flipped_90": "flip 90°", "flipped_180": "flip 180°",
                    "flipped_270": "flip 270°"
                }[root.mon.transform] || root.mon.transform)
                options: [
                    { text: "0°",   value: "normal" },
                    { text: "90°",  value: "rotate_90" },
                    { text: "180°", value: "rotate_180" },
                    { text: "270°", value: "rotate_270" }
                ]
                onPicked: v => root.view.patch(root.index, { transform: v })
            }

            // Mirror this head's output onto ANOTHER connected head — a live
            // wl-mirror clone (not saved in the layout file). "Off" stops it.
            // Needs a connected source, a second head to clone onto, and the Scope
            // that owns the mirror process. Direction: this head -> the chosen one.
            Dropdown {
                menuKey: "mirror"
                caption: "Mirror onto"
                fieldWidth: Config.s(120)
                enabled: root.mon && root.mon.connected && (root.view.connected.length > 1) && !!root.view.scope
                valueText: {
                    var s = root.view.scope;
                    if (s && s.mirroring && root.mon && s.mirrorSource === root.mon.name) return s.mirrorTarget;
                    return "Off";
                }
                options: [{ text: "Off", value: "" }].concat(
                    (root.view.connected || [])
                        .filter(n => n !== (root.mon ? root.mon.name : ""))
                        .map(n => ({ text: n, value: n })))
                onPicked: v => {
                    var s = root.view.scope;
                    if (!s) return;
                    if (v === "") s.stopMirror();
                    else s.startMirror(root.mon.name, v);
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mon ? "at " + root.mon.x + ", " + root.mon.y : ""
                color: Theme.overlay0
                font.pixelSize: Config.s(12)
            }
        }
    }

    // A labelled field that drops a menu of options. `picked` carries the chosen
    // option's `value`; the field only shows `valueText`, so the two can differ
    // (a mode's label vs its {w,h,refresh}).
    component Dropdown: Column {
        id: dd

        property string menuKey: ""
        property string caption: ""
        property string valueText: ""
        property var options: []            // [{ text, value }]
        property real fieldWidth: Config.s(140)
        signal picked(var value)
        // `enabled` is the built-in Item one: setting it false also disables the
        // child pointer handlers, which is exactly the "unplugged head" behaviour.

        readonly property bool open: root.openMenu === dd.menuKey

        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.s(3)

        Txt {
            text: dd.caption
            color: Theme.overlay0
            font.pixelSize: Config.s(10)
        }

        Rectangle {
            id: field
            width: dd.fieldWidth
            height: Config.s(28)
            color: !dd.enabled ? Theme.crust : (fhov.hovered || dd.open ? Theme.surface1 : Theme.surface0)
            border.width: 1
            border.color: dd.open ? Theme.mauve : Theme.surface1

            Txt {
                anchors.left: parent.left
                anchors.leftMargin: Config.s(10)
                anchors.right: caret.left
                anchors.verticalCenter: parent.verticalCenter
                text: dd.valueText
                elide: Text.ElideRight
                color: dd.enabled ? Theme.text : Theme.overlay0
                font.pixelSize: Config.s(13)
            }
            Txt {
                id: caret
                anchors.right: parent.right
                anchors.rightMargin: Config.s(8)
                anchors.verticalCenter: parent.verticalCenter
                text: "▾"
                color: dd.enabled ? Theme.subtext0 : Theme.surface1
                font.pixelSize: Config.s(11)
            }

            HoverHandler { id: fhov; enabled: dd.enabled }
            TapHandler {
                enabled: dd.enabled
                onTapped: root.openMenu = dd.open ? "" : dd.menuKey
            }

            // The menu, opening upward so it stays inside the window. It sits flush
            // on top of the field so their mauve borders meet; the rows are inset
            // by the 1px border so they don't paint over it.
            Rectangle {
                id: menu
                visible: dd.open
                z: 999
                width: field.width
                height: items.height + 2
                y: -height + 1
                color: Theme.base
                border.width: 1
                border.color: Theme.mauve

                Column {
                    id: items
                    x: 1
                    y: 1
                    width: menu.width - 2

                    Repeater {
                        model: dd.options
                        Rectangle {
                            id: opt
                            required property var modelData
                            width: items.width
                            height: Config.s(28)
                            color: ohov.hovered ? Theme.surface1
                                 : (opt.modelData.text === dd.valueText ? Theme.surface0 : Theme.base)
                            Txt {
                                anchors.left: parent.left
                                anchors.leftMargin: Config.s(10)
                                anchors.verticalCenter: parent.verticalCenter
                                text: opt.modelData.text
                                color: Theme.text
                                font.pixelSize: Config.s(13)
                            }
                            HoverHandler { id: ohov }
                            TapHandler { onTapped: { dd.picked(opt.modelData.value); root.openMenu = ""; } }
                        }
                    }
                }
            }
        }
    }
}
