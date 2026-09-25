import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Reach, Sys,
// Volume, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

// Blocks in reach's config.zon order, joined by the same "|" delimiter.
Row {
    id: root

    required property BarStatusData statusData
    required property int fontSize
    required property int trayIconSize
    required property color normalFg

    spacing: 0
    // Keep the first status block separated from the title's app_id, even
    // when the tray is hidden.
    leftPadding: Config.s(8)

    component Block: Txt {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: root.normalFg
        font.pixelSize: root.fontSize
    }
    component Delim: Block {
        text: "|"
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

    Block {
        text: root.statusData.ip
    }
    Delim {}
    Block {
        text: root.statusData.sinkName
        visible: text.length > 0
    }
    Delim {
        visible: root.statusData.sinkName.length > 0
    }
    Block {
        text: Volume.volume + "%"
    }
    Delim {}
    // An unmuted mic warns that the room is being heard; muted is quiet.
    Block {
        text: Volume.micVolume + "%"
        color: Volume.micMuted ? root.normalFg : Theme.red
    }
    Delim {}
    Block {
        text: root.statusData.clock
    }
    Delim {
        visible: Sys.batteryPresent
    }
    Block {
        visible: Sys.batteryPresent
        text: root.statusData.batteryGlyph + " " + Sys.batteryLevel + "%"
        // Red only when actually off mains: `Not charging` on AC under 20% is a
        // threshold hold, not a battery about to die (same reason the card's
        // warning is gated on Sys.onAc).
        color: Sys.charging ? Theme.green
             : Sys.onAc ? Theme.teal
             : (Sys.batteryLevel < 20 ? Theme.red : root.normalFg)
    }
}
