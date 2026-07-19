import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import QtQuick

// Session lock + idle watcher (replaces swaylock + swayidle).
//   - IdleMonitor: 300s idle -> lock (was `swayidle timeout 300 'swaylock -f'`)
//   - Super+P:     `qs ipc call lock lock`
//   - WlSessionLock: real compositor lock (ext-session-lock); PAM auth to unlock.
// Non-singleton so it's instantiated eagerly from shell.qml (a lazy singleton
// would never arm the IdleMonitor).
Scope {
    id: root

    property string pending: ""    // password awaiting PAM's prompt
    property string status: ""
    property string timeStr: ""

    function lock() { sessionLock.locked = true; }

    // Lock at 300s idle (swayidle parity).
    IdleMonitor {
        timeout: 300
        onIsIdleChanged: if (isIdle) root.lock()
    }

    // External trigger for the Super+P keybind.
    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
    }

    // PAM: default config authenticates the current user's password.
    PamContext {
        id: pam
        onPamMessage: if (pam.responseRequired) pam.respond(root.pending)
        onCompleted: (result) => {
            if (result === PamResult.Success) {
                sessionLock.locked = false;
                root.status = "";
            } else {
                root.status = result === PamResult.MaxTries ? "too many attempts" : "incorrect password";
            }
            root.pending = "";
        }
    }
    function tryUnlock(pw) {
        if (pam.active) return;          // one attempt in flight at a time
        root.pending = pw;
        root.status = "checking…";
        pam.start();
    }

    // Clock ticks only while locked.
    Timer {
        interval: 1000; repeat: true; running: sessionLock.locked; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            root.timeStr = ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        // One surface per output; the focused output receives keyboard input.
        WlSessionLockSurface {
            color: Theme.base

            Column {
                anchors.centerIn: parent
                width: 360
                spacing: 24

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.timeStr
                    font.pixelSize: 72; font.bold: true
                }

                Rectangle {
                    width: parent.width; height: 46
                    color: Theme.surface0
                    border.width: 2
                    border.color: pam.active ? Theme.peach : Theme.mauve

                    TextInput {
                        id: field
                        anchors.fill: parent; anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text; font.family: Theme.font; font.pixelSize: 18
                        echoMode: TextInput.Password
                        focus: true
                        enabled: !pam.active
                        onAccepted: { root.tryUnlock(text); text = ""; }
                        Component.onCompleted: forceActiveFocus()
                    }
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.status || "enter password"
                    color: root.status && root.status !== "checking…" ? Theme.red : Theme.subtext0
                    font.pixelSize: 14
                }
            }
        }
    }
}
