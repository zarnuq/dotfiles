pragma ComponentBehavior: Bound
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Blocks in reach's config.zon order, joined by the same "|" delimiter.
Row {
    id: root

    required property BarStatusData statusData
    required property int fontSize
    required property int trayIconSize

    spacing: 0
    // Keep the first status block separated from the title's app_id, even
    // when the tray is hidden.
    leftPadding: Config.s(8)

    component Block: Txt {
        // Trailing "|" in the same colour and font, for as long as this block shows.
        property bool delim: true
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Theme.overlay1
        font.pixelSize: root.fontSize
        rightPadding: delim ? sep.implicitWidth : 0
        Txt {
            id: sep
            visible: parent.delim
            anchors.right: parent.right
            text: "|"
            color: Theme.overlay1
            font.pixelSize: root.fontSize
        }
    }

    component Delim: Block {
        text: "|"
        delim: false
    }

    BarTray {
        id: tray
        anchors.verticalCenter: parent.verticalCenter
        iconSize: root.trayIconSize
    }
    // The tray's padding and this extra gap keep icons clear of the delimiter.
    Delim {
        visible: tray.visible
        rightPadding: Config.s(8)
    }

    Loader {
        active: Config.on("agentDesktop")
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: Txt {
            font.pixelSize: root.fontSize
            color: !AgentDesktopState.status.running ? Theme.overlay1
                 : AgentDesktopState.status.paused ? Theme.peach : Theme.green
            text: !AgentDesktopState.status.running ? "AI off"
                : AgentDesktopState.status.paused ? "AI paused"
                : "AI · " + (AgentDesktopState.status.windows || []).length
            MouseArea {
                anchors.fill: parent
                onClicked: AgentDesktopState.panelOpen = !AgentDesktopState.panelOpen
            }
        }
    }
    Delim { visible: Config.on("agentDesktop") }

    Block {
        visible: Recorder.recording
        text: "󰑊 REC"
        color: Theme.red
    }
    Block {
        text: root.statusData.ip
    }
    Block {
        text: root.statusData.sinkName
        visible: text.length > 0
    }
    Block {
        text: "󰂱 " + root.statusData.bluetooth
        visible: root.statusData.bluetooth !== ""
    }
    Block {
        text: Volume.volume + "%"
    }
    // An unmuted mic warns that the room is being heard; muted is quiet.
    Block {
        text: Volume.micVolume + "%"
        color: Volume.micMuted ? Theme.overlay1 : Theme.red
    }
    Block {
        text: root.statusData.clock
        color: Theme.subtext1
        delim: Power.present
    }
    Block {
        visible: Power.present
        delim: false
        text: root.statusData.batteryGlyph + " " + Power.level + "%"
        // Bright grey like the clock, green while on mains (onAc, not
        // charging: a threshold hold on AC is still plugged in). Low
        // (Power.low, gated on onAc — a threshold hold on AC is not a dying
        // battery) turns it into a red block with white text.
        color: Power.low ? Theme.alertFg : Power.onAc ? Theme.green : Theme.subtext1
        leftPadding: Power.low ? Config.s(6) : 0
        rightPadding: leftPadding
        Rectangle {
            z: -1
            anchors.fill: parent
            visible: Power.low
            color: Theme.red
            radius: Theme.borderRadius
        }
    }
}
