import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import QtQuick

// Everything that ends or suspends the session, behind one key: Super+P locks
// (`qs ipc call lock lock`), and the session actions live ON the lock screen
// rather than in an overlay of their own.
//
// Putting them there is what removed the third file: a menu that offers "Lock"
// and a lock screen that offers nothing were two halves of the same thing.
//
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

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
    }

    // ---- session actions --------------------------------------------------
    readonly property var actions: [
        { icon: "󰐥", label: "Power off", act: "poweroff" },
        { icon: "󰜉", label: "Reboot",    act: "reboot" },
        { icon: "󰍃", label: "Log out",   act: "logout" }
    ]

    // -1 = nothing armed. Every entry here ends the session or the machine, so
    // none of them fires on a single keystroke or a single click: an arrow or
    // Tab (or a click) arms one, and only then does Return (or a second click)
    // run it. Down/Right step into the row, Up/Left step back out of it.
    // Typing disarms — a password going into the field can't end up powering
    // the box off because Return came after a stray Tab.
    property int armed: -1

    Process {
        id: powerProc
        property string act: ""
        onExited: (code) => {
            if (code === 0) return;
            root.armed = -1;
            // Nothing to fall back to: `doas` wants a password on a tty, and
            // the lock surface is above every window, so the floating-kitty
            // prompt the old unlocked menu used would be invisible here.
            root.status = powerProc.act + " failed — check the doas rule for it";
        }
    }

    function run(i) {
        if (i < 0 || i >= root.actions.length) return;
        var act = root.actions[i].act;

        if (act === "logout") {
            // reach's own .quit SIGTERMs river (its parent) rather than just
            // exiting, so the compositor is never left running without a window
            // manager. Signalling river directly ends the session the same way.
            Quickshell.execDetached(["pkill", "-TERM", "-x", "river"]);
            return;
        }

        // No polkit or logind on this runit box, and /usr/bin/poweroff (a
        // symlink to the runit-shutdown dispatcher) self-elevates with doas
        // anyway — so ask doas directly. -n makes it fail fast rather than
        // block on a password prompt no one can reach: the lock surface is
        // above every window, so there is no tty to type into.
        //
        // The command is the BARE name because doas matches what was typed,
        // and /etc/doas.conf here says `permit nopass :wheel cmd poweroff`.
        // Passing /usr/bin/poweroff misses that rule and falls through to
        // `permit persist :wheel`, which wants a password — verify any change
        // with `doas -C /etc/doas.conf <cmd>`, which prints the verdict and
        // runs nothing.
        powerProc.act = act;
        powerProc.command = ["doas", "-n", act];
        powerProc.running = true;
    }

    // ---- unlock -----------------------------------------------------------
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
        onLockedChanged: if (locked) { root.armed = -1; root.status = ""; }

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
                        onTextChanged: root.armed = -1

                        // The field keeps focus the whole time — the action row
                        // is driven from here instead of taking focus off it,
                        // so a password typed at any moment still lands in the
                        // box it was meant for.
                        Keys.onPressed: function (e) {
                            var n = root.actions.length;
                            if (e.key === Qt.Key_Tab || e.key === Qt.Key_Down || e.key === Qt.Key_Right) {
                                root.armed = root.armed < 0 ? 0 : (root.armed + 1) % n;
                            }
                            // Backing off the first action returns to the field —
                            // the arrows are the way out of the row as well as in.
                            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Left) { root.armed = root.armed <= 0 ? -1 : root.armed - 1; }
                            else if (e.key === Qt.Key_Backtab) { root.armed = (root.armed <= 0 ? n : root.armed) - 1; }
                            else if (e.key === Qt.Key_Escape) { root.armed = -1; }
                            else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && root.armed >= 0) { root.run(root.armed); }
                            else { return; }
                            e.accepted = true;
                        }
                        Component.onCompleted: forceActiveFocus()
                    }
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.status || (root.armed >= 0
                                          ? root.actions[root.armed].label + " — Return to confirm"
                                          : "enter password")
                    color: root.armed >= 0 ? Theme.peach
                           : (root.status && root.status !== "checking…") ? Theme.red : Theme.subtext0
                    font.pixelSize: 14
                }

                // Session actions. Tab through them, or click once to arm and
                // again to run.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Repeater {
                        model: root.actions

                        Rectangle {
                            id: btn
                            required property var modelData
                            required property int index
                            readonly property bool isArmed: index === root.armed

                            width: 112; height: 40
                            color: isArmed ? Theme.surface0 : "transparent"
                            border.width: 1
                            border.color: isArmed ? Theme.peach : Theme.surface1

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (btn.isArmed) root.run(index);
                                    else root.armed = index;
                                }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    color: btn.isArmed ? Theme.peach : Theme.subtext0
                                    font.pixelSize: 16
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: btn.isArmed ? Theme.text : Theme.subtext0
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
