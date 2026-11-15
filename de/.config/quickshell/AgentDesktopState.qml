pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool panelOpen: false
    property var status: ({ running: false, paused: false, manual: false, windows: [] })
    property string error: ""
    readonly property string runtimePath: Quickshell.env("AGENT_DESK_RUNTIME") || Config.runtimeDir + "/agent-desk"
    readonly property string executable: Quickshell.env("AGENT_DESK_COMMAND") || Quickshell.env("HOME") + "/.local/bin/agent-desk"

    function run(args): void {
        if (action.running) return;
        root.error = "";
        action.command = [root.executable].concat(args);
        action.running = true;
    }

    FileView {
        id: stateFile
        path: root.runtimePath + "/status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.status = JSON.parse(stateFile.text());
            } catch (e) {
                root.error = "Cannot read desktop status";
            }
        }
        onLoadFailed: root.status = ({ running: false, paused: false, manual: false, windows: [] })
    }

    // Also discovers a runtime directory created after the shell started.
    // FileView reads directly; no subprocess poll is needed.
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: stateFile.reload()
    }

    Process {
        id: action
        stderr: StdioCollector { onStreamFinished: root.error = text.trim() }
        onExited: stateFile.reload()
    }
}
