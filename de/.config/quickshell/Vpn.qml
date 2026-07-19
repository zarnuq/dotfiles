import Quickshell
import Quickshell.Io
import QtQuick

// eww `vpn` window. Bottom-left, x=210 y=300, 210 wide.
// Lists .ovpn profiles (vpn-manager.sh); click to toggle. status = connected name, "" = off.
Widget {
    id: root
    pad: 0                                    // header/list manage their own padding
    anchors { bottom: true; left: true }
    margins { bottom: s(300); left: s(210) }
    implicitWidth: s(210)
    implicitHeight: s(150)

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/vpn-manager.sh"
    property var vpns: []       // [{ name, file }]
    property string status: ""  // connected profile name, or ""
    readonly property bool connected: status !== ""

    Process {
        id: listProc
        command: [root.script, "list"]
        stdout: StdioCollector { onStreamFinished: { try { root.vpns = JSON.parse(text) || []; } catch (e) { root.vpns = []; } } }
    }
    Process {
        id: statusProc
        command: [root.script, "status"]
        stdout: StdioCollector { onStreamFinished: root.status = text.trim() }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: listProc.running = true }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: statusProc.running = true }

    Column {
        anchors.fill: parent

        // Header: overall connection state.
        Row {
            width: parent.width
            height: root.s(46)
            leftPadding: root.s(16); rightPadding: root.s(16)
            spacing: root.s(10)
            Txt {
                text: root.connected ? "󰌆" : "󰌊"; font.pixelSize: root.s(18)
                color: root.connected ? Theme.green : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
            Txt {
                text: root.connected ? root.status : "VPN Disconnected"
                color: root.connected ? Theme.green : Theme.text
                font.pixelSize: root.s(14); elide: Text.ElideRight
                width: parent.width - x - root.s(16); anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Profile list.
        ListView {
            width: parent.width
            height: parent.height - root.s(46)
            clip: true
            topMargin: root.s(8); leftMargin: root.s(8); rightMargin: root.s(8)
            spacing: root.s(2)
            model: root.vpns

            delegate: Rectangle {
                id: entry
                required property var modelData
                width: ListView.view.width - root.s(16)
                radius: root.s(8)
                implicitHeight: label.height + root.s(20)
                readonly property bool active: modelData.name === root.status
                color: active ? Qt.rgba(0.65, 0.89, 0.63, mouse.containsMouse ? 0.3 : 0.15)
                              : (mouse.containsMouse ? Theme.surface0 : "transparent")

                Row {
                    id: label
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: root.s(14); rightMargin: root.s(14) }
                    spacing: root.s(10)
                    Txt { text: entry.active ? "󰌆" : "󰌊"; font.pixelSize: root.s(13)
                          color: entry.active ? Theme.green : Theme.text }
                    Txt { text: entry.modelData.name; font.pixelSize: root.s(13); elide: Text.ElideRight
                          color: entry.active ? Theme.green : Theme.text
                          width: parent.width - x }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached([root.script, "toggle", entry.modelData.file])
                }
            }
        }
    }
}
