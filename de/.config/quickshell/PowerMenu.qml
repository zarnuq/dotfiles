import Quickshell
import QtQuick

// Session actions on one key: `qs ipc call power toggle` (Super+Escape).
// Built on Picker, so overlay/keyboard-focus/IPC are shared with the launcher
// and wallpaper picker — this file is just the list and what each entry runs.
Picker {
    id: root

    ipcTarget: "power"
    allScreens: true      // session actions are worth showing wherever you're looking

    readonly property real scale: Config.onLaptop ? 0.85 : 1.0
    function s(n) { return Math.round(n * scale); }

    readonly property int rowHeight: s(52)
    boxWidth: s(300)
    boxHeight: rowHeight * entries.length

    // Lock only appears when Lock.qml is actually built — otherwise the entry
    // would call an IPC target that doesn't exist (Config.lock is off today).
    readonly property var entries: {
        var e = [];
        e.push({ icon: "󰐥", label: "Power off", act: "poweroff" });
        e.push({ icon: "󰍃", label: "Log out", act: "logout" });
        e.push({ icon: "󰜉", label: "Reboot", act: "reboot" });
        if (Config.lock) e.push({ icon: "󰌾", label: "Lock", act: "lock" });
        return e;
    }

    // Nothing is armed on open: with lock disabled every entry here ends the
    // session or the machine, so a stray Return shouldn't be able to fire one.
    // Move with j/k or the arrows first. Change to 0 to preselect the top row.
    property int selected: -1

    function run(i) {
        if (i < 0 || i >= root.entries.length) return;
        var act = root.entries[i].act;
        root.hide();

        if (act === "lock") {
            Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"]);
        } else if (act === "logout") {
            // reach's own .quit SIGTERMs river (its parent) rather than just
            // exiting, so the compositor is never left running without a window
            // manager. Signalling river directly ends the session the same way.
            Quickshell.execDetached(["pkill", "-TERM", "-x", "river"]);
        } else {
            // No polkit or logind on this runit box, so poweroff/reboot need
            // doas — and doas wants a password, which needs a terminal. Same
            // floating-kitty escape hatch ssvfzf uses for system services.
            Quickshell.execDetached(["kitty", "--class", "float", "-e", "doas", act]);
        }
    }

    box: Component {
        Item {
            id: content
            focus: true

            function reset() { root.selected = -1; content.forceActiveFocus(); }

            Keys.onPressed: function (e) {
                var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier));
                if (e.key === Qt.Key_Escape) { root.hide(); }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.run(root.selected); }
                else if (e.key === Qt.Key_Down || (e.key === Qt.Key_J && (plain || (e.modifiers & Qt.ControlModifier)))) {
                    root.selected = Math.min(root.selected + 1, root.entries.length - 1);
                } else if (e.key === Qt.Key_Up || (e.key === Qt.Key_K && (plain || (e.modifiers & Qt.ControlModifier)))) {
                    root.selected = Math.max(root.selected - 1, 0);
                } else { return; }
                e.accepted = true;
            }

            Column {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: root.entries

                    Rectangle {
                        required property var modelData
                        required property int index
                        width: content.width
                        height: root.rowHeight
                        color: index === root.selected ? "#11111b" : "transparent"

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selected = index
                            onClicked: { root.selected = index; root.run(index); }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: root.s(18)
                            spacing: root.s(16)

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.s(24)
                                text: modelData.icon
                                color: index === root.selected ? Theme.mauve : Theme.subtext0
                                font.pixelSize: root.s(20)
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: index === root.selected ? "#bac2de" : Theme.text
                                font.pixelSize: root.s(17)
                            }
                        }
                    }
                }
            }
        }
    }
}
