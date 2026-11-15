pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    IpcHandler {
        target: "agentdesk"
        function toggle(): void { AgentDesktopState.panelOpen = !AgentDesktopState.panelOpen; }
        function hide(): void { AgentDesktopState.panelOpen = false; }
        function open(): void { AgentDesktopState.panelOpen = true; }
    }

    PanelWindow {
        id: panel
        visible: AgentDesktopState.panelOpen
        screen: Config.pinScreen
        anchors { top: true; right: true }
        margins { top: Config.s(30); right: Config.s(8) }
        implicitWidth: Config.s(380)
        implicitHeight: contents.implicitHeight + Config.s(24)
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        color: Theme.base

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Config.s(1)
            border.color: Theme.surface1
            radius: Theme.borderRadius
        }

        Column {
            id: contents
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Config.s(12) }
            spacing: Config.s(8)

            Row {
                width: parent.width
                Txt {
                    width: contents.width - closeLabel.implicitWidth
                    text: "Agent desktop"
                    font.pixelSize: Config.s(16)
                    font.bold: true
                }
                Txt {
                    id: closeLabel
                    text: "×"
                    font.pixelSize: Config.s(18)
                    MouseArea { anchors.fill: parent; onClicked: AgentDesktopState.panelOpen = false }
                }
            }
            Txt {
                width: parent.width
                font.pixelSize: Config.s(13)
                color: AgentDesktopState.status.running ? Theme.green : Theme.overlay1
                text: !AgentDesktopState.status.running ? "Stopped"
                    : AgentDesktopState.status.manual ? "You have control · agent paused"
                    : AgentDesktopState.status.paused ? "Agent paused" : "Agent active"
            }
            Repeater {
                model: AgentDesktopState.status.windows || []
                delegate: Txt {
                    id: windowEntry
                    required property var modelData
                    width: contents.width
                    font.pixelSize: Config.s(12)
                    text: (windowEntry.modelData.focused ? "● " : "○ ")
                        + (windowEntry.modelData.title || windowEntry.modelData.appId)
                    elide: Text.ElideRight
                }
            }
            Row {
                spacing: Config.s(6)
                Repeater {
                    model: AgentDesktopState.status.running
                        ? [{label: "View", args: ["view"]},
                           {label: "Take control", args: ["view", "--control"]},
                           {label: AgentDesktopState.status.paused ? "Resume" : "Pause",
                            args: [AgentDesktopState.status.paused ? "resume" : "pause"]},
                           {label: "Stop", args: ["stop"]}]
                        : [{label: "Start", args: ["start"]}]
                    delegate: Rectangle {
                        id: button
                        required property var modelData
                        implicitWidth: buttonText.implicitWidth + Config.s(14)
                        implicitHeight: Config.s(28)
                        color: buttonMouse.containsMouse ? Theme.surface1 : Theme.surface0
                        radius: Theme.borderRadius
                        Txt {
                            id: buttonText
                            anchors.centerIn: parent
                            text: button.modelData.label
                            font.pixelSize: Config.s(12)
                        }
                        MouseArea {
                            id: buttonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: AgentDesktopState.run(button.modelData.args)
                        }
                    }
                }
            }
            Txt {
                width: parent.width
                visible: text.length > 0
                text: AgentDesktopState.error || AgentDesktopState.status.error || ""
                color: Theme.red
                font.pixelSize: Config.s(11)
                wrapMode: Text.Wrap
            }
        }
    }
}
