pragma ComponentBehavior: Bound
import QtQuick
import ".."

// The selected head's settings, as steppers rather than drop-downs: the shell has
// no combo-box idiom (its menus are Picker rows), and a stepper is both less code
// and usable from the keyboard, which a popup list inside a tiled window is not.
Item {
    id: root

    required property var view
    readonly property int index: view.selected
    readonly property var mon: (view.working && index >= 0 && index < view.working.length)
                               ? root.view.working[index] : null
    readonly property var modes: mon ? view.modesFor(mon.name) : []

    implicitHeight: root.view.s(54)

    Rectangle {
        anchors.fill: parent
        color: Theme.surface0
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: root.view.s(12)
        anchors.rightMargin: root.view.s(12)
        spacing: root.view.s(14)

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: root.view.s(130)
            spacing: root.view.s(2)
            Txt {
                text: root.mon ? root.mon.name : "no output"
                color: Theme.text
                font.pixelSize: root.view.s(14)
            }
            Txt {
                text: !root.mon ? ""
                    : !root.mon.included ? "not in layout"
                    : !root.mon.connected ? "not connected" : "in layout"
                color: root.mon && root.mon.connected && root.mon.included ? Theme.overlay0 : Theme.peach
                font.pixelSize: root.view.s(11)
            }
        }

        // Mode. A head that is unplugged offers no mode list, so its recorded
        // mode is shown and left alone rather than being reset to something this
        // machine happens to support.
        Stepper {
            caption: "Mode"
            value: !root.mon ? "—"
                 : (root.mon.w ? root.mon.w + "×" + root.mon.h : "preferred")
                   + (root.mon.refresh ? "  " + Math.round(root.mon.refresh / 1000) + "Hz" : "")
            enabled: root.mon && root.modes.length > 0
            onStep: direction => root.view.stepMode(root.index, direction)
        }

        Stepper {
            caption: "Scale"
            value: root.mon ? root.mon.scale.toFixed(2) : "—"
            enabled: !!root.mon
            onStep: direction => root.view.stepScale(root.index, direction)
        }

        Stepper {
            caption: "Rotation"
            value: !root.mon ? "—" : ({
                "normal": "0°", "rotate_90": "90°", "rotate_180": "180°", "rotate_270": "270°",
                "flipped": "flip", "flipped_90": "flip 90°", "flipped_180": "flip 180°",
                "flipped_270": "flip 270°"
            }[root.mon.transform] || root.mon.transform)
            enabled: !!root.mon
            onStep: root.view.cycleTransform(root.index)
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.mon ? root.mon.x + ", " + root.mon.y : ""
            color: Theme.overlay0
            font.pixelSize: root.view.s(12)
        }

        MonitorButton {
            anchors.verticalCenter: parent.verticalCenter
            label: root.mon && root.mon.included ? "Remove" : "Add"
            enabled: !!root.mon
            onClicked: root.view.toggleIncluded(root.index)
        }
    }

    // A caption over a ◀ value ▶ row. `onStep` gets -1 or +1; the rotation
    // stepper ignores the direction and cycles, which is why the signal carries
    // it rather than the handler assuming.
    component Stepper: Column {
        id: stepper

        property string caption: ""
        property string value: ""
        signal step(int direction)

        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.s(2)

        Txt {
            text: stepper.caption
            color: Theme.overlay0
            font.pixelSize: Config.s(10)
        }

        Row {
            spacing: Config.s(6)

            StepArrow { owner: stepper; direction: -1 }
            Txt {
                text: stepper.value
                color: stepper.enabled ? Theme.text : Theme.overlay0
                font.pixelSize: Config.s(13)
                horizontalAlignment: Text.AlignHCenter
                width: Config.s(108)
                anchors.verticalCenter: parent.verticalCenter
            }
            StepArrow { owner: stepper; direction: 1 }
        }
    }

    component StepArrow: Txt {
        id: arrow
        required property var owner      // the Stepper this steps
        required property int direction

        text: direction < 0 ? "◀" : "▶"
        color: owner.enabled ? Theme.subtext0 : Theme.surface1
        font.pixelSize: Config.s(12)
        anchors.verticalCenter: parent.verticalCenter
        TapHandler {
            enabled: arrow.owner.enabled
            onTapped: arrow.owner.step(arrow.direction)
        }
    }
}
