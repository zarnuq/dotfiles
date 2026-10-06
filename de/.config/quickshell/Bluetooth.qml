pragma ComponentBehavior: Bound
import Quickshell.Bluetooth
import QtQuick

// Bluetooth menu (Super+R t / `qs ipc call bluetooth toggle`), replacing
// blueman. Native Quickshell.Bluetooth (BlueZ over D-Bus): every row is live,
// nothing is polled.
//
// Rows: the adapter's power switch, paired devices, then whatever discovery
// has found nearby (it runs only while the menu is open). Enter powers /
// connects / pairs+trusts+connects; `d` disconnects, `x` forgets a paired device.
//
// Quickshell registers no pairing agent, so BlueZ pairs as NoInputNoOutput:
// "just works" devices (headphones, most mice and keyboards) pair, and one that
// wants a passkey fails. Pair those with `bluetoothctl` in a terminal.
Picker {
    id: root

    ipcTarget: "bluetooth"

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    property string status: ""

    // Discovery belongs to the D-Bus client that asked for it, so it stops
    // when the menu closes (or quickshell exits).
    Binding {
        when: root.adapter !== null
        target: root.adapter
        property: "discovering"
        value: root.open && root.powered
    }

    // A nameless advertiser lists its address as its name (dashes for colons):
    // beacons and phones nobody is pairing with. Nearby leaves those out.
    function named(d) { return d.name !== "" && d.name.replace(/-/g, ":") !== d.address; }

    rows: {
        if (!root.adapter) return [{ kind: "none", label: "no Bluetooth adapter" }];
        var r = [{ kind: "power", label: "Bluetooth" }];
        if (!root.powered) return r;
        var all = root.adapter.devices.values;
        var paired = all.filter(d => d.paired).sort((a, b) => b.connected - a.connected);
        var nearby = all.filter(d => !d.paired && root.named(d));
        if (paired.length) r.push({ kind: "header", label: "Paired" });
        paired.forEach(d => r.push({ kind: "dev", dev: d }));
        if (nearby.length) r.push({ kind: "header", label: "Nearby" });
        nearby.forEach(d => r.push({ kind: "dev", dev: d }));
        return r;
    }

    rowHeight: s(36)
    barHeight: s(30)
    minBoxHeight: s(140)
    boxWidth: s(460)

    // ── actions: the menu stays open to show how they went ───────────────
    // The device being paired. Pairing has no failure signal: it ends with
    // `pairing` false, and `paired` says whether it took.
    property BluetoothDevice pairing: null
    Connections {
        target: root.pairing
        function onPairingChanged(): void {
            var d = root.pairing;
            if (d.pairing) return;
            root.pairing = null;
            if (!d.paired) { root.status = "pairing " + d.name + " failed — passkey devices need bluetoothctl"; return; }
            root.status = "";
            d.trusted = true;
            d.connect();
        }
    }

    function activate(i): void {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.kind === "power") {
            root.adapter.enabled = !root.powered;
        } else if (row.kind === "dev" && !row.dev.connected) {
            root.status = "";
            if (row.dev.paired) { row.dev.connect(); return; }
            root.pairing = row.dev;
            root.status = "pairing " + row.dev.name + "…";
            row.dev.pair();
        }
    }

    function deviceAction(i, verb): void {
        if (!selectable(i) || rows[i].kind !== "dev") return;
        var d = rows[i].dev;
        if (verb === "disconnect" && d.connected) d.disconnect();
        else if (verb === "remove" && d.paired) d.forget();
    }

    onOpenChanged: if (!open) root.status = ""

    box: Component {
        PickerList {
            picker: root
            status: root.status
            hint: "enter connect · d disconnect · x forget"

            onExtraKey: function (e) {
                if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return;
                if (e.key === Qt.Key_D) root.deviceAction(root.selected, "disconnect");
                else if (e.key === Qt.Key_X) root.deviceAction(root.selected, "remove");
                else return;
                e.accepted = true;
            }

            rowDelegate: PickerRow {
                id: rowItem
                readonly property var dev: rowItem.isHeader ? null : rowItem.modelData.dev || null
                readonly property bool busy: rowItem.dev !== null
                    && (rowItem.dev.state === BluetoothDeviceState.Connecting || rowItem.dev.pairing)
                readonly property bool on_: rowItem.dev ? rowItem.dev.connected
                                            : rowItem.modelData.kind === "power" && root.powered

                picker: root
                width: parent.width
                current: rowItem.on_
                onActivated: root.activate(rowItem.index)

                icon: rowItem.isHeader ? ""
                      : rowItem.modelData.kind === "power" ? (root.powered ? "󰂯" : "󰂲")
                      : rowItem.modelData.kind === "none" ? "󰂲"
                      : rowItem.on_ ? "󰂱" : "󰂯"
                label: rowItem.isHeader ? "" : rowItem.dev ? rowItem.dev.name : rowItem.modelData.label
                trailing: rowItem.isHeader ? ""
                          : rowItem.modelData.kind === "power" ? (root.powered ? "on" : "off")
                          : rowItem.busy ? "…"
                          : rowItem.on_ ? "connected"
                          : rowItem.dev && !rowItem.dev.paired ? "pair" : ""
                trailingWidth: root.s(90)
                trailingColor: rowItem.on_ ? Theme.mauve : Theme.subtext0
            }

        }
    }
}
