import Quickshell
import Quickshell.Io
import QtQuick

// eww `notifications` window. Bottom-left, x=140 y=600, 280 wide.
// mako history via makoctl; header toggles DND / clears on-screen.
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(600); left: s(140) }
    implicitWidth: s(280)
    implicitHeight: s(150)

    property var notifs: []      // [{ app, summary, body }]
    property bool paused: false

    Process {
        id: histProc
        command: ["sh", "-c",
            "makoctl history -j | jq -c '[.[] | {app: (.app_name // \"Unknown\"), summary: (.summary // \"No summary\"), body: (.body // \"\")}] | .[:5]' 2>/dev/null || echo '[]'"]
        stdout: StdioCollector { onStreamFinished: { try { root.notifs = JSON.parse(text) || []; } catch (e) { root.notifs = []; } } }
    }
    Process {
        id: modeProc
        command: ["sh", "-c", "makoctl mode 2>/dev/null | grep -q '^do-not-disturb$' && echo true || echo false"]
        stdout: StdioCollector { onStreamFinished: root.paused = (text.trim() === "true") }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { histProc.running = true; modeProc.running = true; }
    }

    Column {
        anchors.fill: parent
        spacing: root.s(8)

        // Header: label + DND toggle + clear.
        Row {
            id: header
            width: parent.width
            Txt {
                text: "notifications"; color: Theme.subtext0; font.pixelSize: root.s(12)
                width: parent.width - dnd.width - clear.width - 2 * root.s(8)
                verticalAlignment: Text.AlignVCenter
            }
            HeaderBtn {
                id: dnd
                leftMargin: root.s(8)
                icon: root.paused ? "󰂛" : "󰂚"; size: root.s(14)
                onClicked: Quickshell.execDetached(["makoctl", "mode", "-t", "do-not-disturb"])
            }
            HeaderBtn {
                id: clear
                leftMargin: root.s(8)
                icon: "󰆴"; size: root.s(14)
                onClicked: Quickshell.execDetached(["makoctl", "dismiss", "-a"])
            }
        }

        ListView {
            width: parent.width
            height: parent.height - header.height - parent.spacing
            clip: true
            spacing: root.s(5)
            model: root.notifs

            delegate: Rectangle {
                id: notif
                required property var modelData
                width: ListView.view.width
                color: Theme.surface0; radius: root.s(8)
                implicitHeight: card.height + root.s(16)
                Column {
                    id: card
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: root.s(8); rightMargin: root.s(8) }
                    Txt { text: notif.modelData.app; color: Theme.subtext0; font.pixelSize: root.s(10) }
                    Txt { text: notif.modelData.summary; font.pixelSize: root.s(12)
                          width: parent.width; wrapMode: Text.WordWrap }
                }
            }
        }
    }
}
