pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

// Notification history + DND (Super+R o / `qs ipc call notifications toggle`),
// a menu like Network/Bluetooth rather than a card always on screen. History
// and DND come from NotificationService. Enter on the first row toggles DND,
// on an entry copies its text; `x` drops an entry, `c` clears everything.
Picker {
    id: root

    ipcTarget: "notifications"

    // Re-read on open so the ages are current; nothing ticks while it's up.
    property real now: Date.now()
    onOpened: root.now = Date.now()

    function age(t) {
        var m = Math.floor((root.now - t) / 60000);
        return m < 1 ? "now" : m < 60 ? m + "m" : m < 1440 ? Math.floor(m / 60) + "h" : Math.floor(m / 1440) + "d";
    }

    rows: {
        var r = [{ kind: "dnd" }];
        var h = NotificationService.history;
        r.push({ kind: "header", label: h.length ? "History" : "" });
        if (!h.length) r.push({ kind: "none" });
        h.forEach((n, i) => r.push({ kind: "notif", n: n, i: i }));
        return r;
    }

    rowHeight: s(36)
    barHeight: s(30)
    boxWidth: s(560)

    function activate(i): void {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.kind === "dnd") NotificationService.toggleDnd();
        else if (row.kind === "notif") {
            Quickshell.execDetached(["wl-copy", "--", row.n.summary + (row.n.body ? "\n" + row.n.body : "")]);
            root.hide();
        }
    }

    box: Component {
        PickerList {
            picker: root

            onExtraKey: function (e) {
                if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return;
                var row = root.rows[root.selected];
                if (e.key === Qt.Key_X && row && row.kind === "notif") NotificationService.remove(row.i);
                else if (e.key === Qt.Key_C) NotificationService.clear();
                else return;
                e.accepted = true;
            }

            rowDelegate: PickerRow {
                id: rowItem
                readonly property var n: isHeader ? null : modelData.n || null
                readonly property bool dnd: modelData.kind === "dnd"

                picker: root
                width: parent.width
                current: rowItem.dnd && NotificationService.paused
                onActivated: root.activate(rowItem.index)

                icon: rowItem.isHeader || rowItem.n ? ""
                      : rowItem.dnd ? (NotificationService.paused ? "󰂛" : "󰂚") : "󰂚"
                iconColor: (rowItem.current || rowItem.sel) ? Theme.mauve : Theme.subtext0
                label: rowItem.isHeader ? ""
                       : rowItem.dnd ? "Do not disturb"
                       : rowItem.n ? rowItem.n.app + "  ·  " + rowItem.n.summary
                       : "no notifications"
                labelColor: rowItem.modelData.kind === "none" ? Theme.subtext0
                            : rowItem.sel ? Theme.rowSelectFg : Theme.text
                trailing: rowItem.dnd ? (NotificationService.paused ? "on" : "off")
                          : rowItem.n ? root.age(rowItem.n.time) : ""
                trailingWidth: root.s(60)
                trailingColor: rowItem.current ? Theme.mauve : Theme.subtext0
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                text: "enter toggle / copy · x remove · c clear all"
                color: Theme.surface1
                elide: Text.ElideRight
                font.pixelSize: root.s(13)
            }
        }
    }
}
