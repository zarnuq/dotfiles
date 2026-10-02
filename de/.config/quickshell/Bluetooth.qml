pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Bluetooth menu (Super+R t / `qs ipc call bluetooth toggle`), replacing
// blueman. Driven by `bluetoothctl`, the way Network.qml drives nmcli: the
// shell's quickshell is built without its Bluetooth module (USE=-bluetooth),
// and the CLI needs no rebuild.
//
// Rows: the adapter's power switch, paired devices, then whatever a scan has
// found nearby. Enter powers / connects / pairs+trusts+connects; `d`
// disconnects, `x` forgets a paired device, `r` rescans.
//
// Pairing goes through bluetoothctl's own default agent, which handles "just
// works" devices (headphones, most mice and keyboards). One that wants a
// passkey typed or confirmed fails with bluetoothctl's message in the status
// line — there is nothing on a layer surface to answer the prompt with.
Picker {
    id: root

    ipcTarget: "bluetooth"

    property bool adapter: true      // false: no controller at all
    property bool powered: false
    property var devices: []         // [{ mac, name, paired, connected }]
    property string status: ""

    // One snapshot: power + every known device + which are paired/connected.
    // Each line tagged so one parser sorts them out.
    Poll {
        id: bt
        running: root.open
        interval: 3000
        command: ["sh", "-c",
            "s=$(bluetoothctl show) || exit; " +
            "case \"$s\" in *Controller*) ;; *) echo N:; exit;; esac; " +
            "case \"$s\" in *'Powered: yes'*) echo P:1;; *) echo P:0;; esac; " +
            "bluetoothctl devices | sed -n 's/^Device /A:/p'; " +
            "bluetoothctl devices Paired | sed -n 's/^Device /B:/p'; " +
            "bluetoothctl devices Connected | sed -n 's/^Device /C:/p'"]
        onData: text => {
            var lines = text.split("\n"), byMac = {}, list = [];
            root.adapter = lines.indexOf("N:") < 0;
            root.powered = lines.indexOf("P:1") >= 0;
            lines.forEach(l => {
                var tag = l.slice(0, 2), mac = l.slice(2, 19);
                if (tag === "A:") list.push(byMac[mac] = { mac: mac, name: l.slice(20) || mac, paired: false, connected: false });
                else if (tag === "B:" && byMac[mac]) byMac[mac].paired = true;
                else if (tag === "C:" && byMac[mac]) byMac[mac].connected = true;
            });
            root.devices = list;
        }
    }

    // Discovery belongs to the D-Bus client that asked for it, so a detached
    // bluetoothctl with a timeout scans for that long and then stops by itself.
    Timer {
        running: root.open && root.powered
        interval: 20000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.rescan()
    }
    function rescan(): void {
        Quickshell.execDetached(["bluetoothctl", "--timeout", "15", "scan", "on"]);
    }

    // A nameless advertiser lists its address as its name (dashes for colons):
    // beacons and phones nobody is pairing with. Nearby leaves those out.
    function named(d) { return d.name.replace(/-/g, ":") !== d.mac; }

    rows: {
        if (!root.adapter) return [{ kind: "none", label: "no Bluetooth adapter" }];
        var r = [{ kind: "power", label: "Bluetooth" }];
        if (!root.powered) return r;
        var paired = root.devices.filter(d => d.paired).sort((a, b) => b.connected - a.connected);
        var nearby = root.devices.filter(d => !d.paired && root.named(d));
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

    // ── actions: one at a time, menu stays open to show how it went ──────
    Process {
        id: act
        stdout: StdioCollector { id: actOut }
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            // bluetoothctl reports most failures on stdout ("Failed to
            // connect: org.bluez.Error…"), so take the last line of either.
            var out = (actErr.text + "\n" + actOut.text).trim().split("\n");
            root.status = code === 0 ? "" : (out.filter(l => /fail|error|not available/i.test(l)).pop()
                                             || "failed (exit " + code + ")");
            bt.refresh();
        }
    }

    function run(script, note): void {
        if (act.running) return;
        root.status = note;
        act.command = ["sh", "-c", script];
        act.running = true;
    }

    function activate(i): void {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.kind === "power") {
            root.run("bluetoothctl power " + (root.powered ? "off" : "on"),
                     root.powered ? "turning Bluetooth off…" : "turning Bluetooth on…");
        } else if (row.kind === "dev" && !row.dev.connected) {
            var m = row.dev.mac;   // [0-9A-F:] only — straight from bluetoothctl's listing
            root.run(row.dev.paired ? "bluetoothctl connect " + m
                     : "bluetoothctl pair " + m + " && bluetoothctl trust " + m + " && bluetoothctl connect " + m,
                     (row.dev.paired ? "connecting " : "pairing ") + row.dev.name + "…");
        }
    }

    function deviceAction(i, verb): void {
        if (!selectable(i) || rows[i].kind !== "dev") return;
        var d = rows[i].dev;
        if (verb === "disconnect" && d.connected) root.run("bluetoothctl disconnect " + d.mac, "disconnecting " + d.name + "…");
        else if (verb === "remove" && d.paired) root.run("bluetoothctl remove " + d.mac, "forgetting " + d.name + "…");
    }

    onOpenChanged: if (!open) root.status = ""

    box: Component {
        PickerList {
            picker: root

            onExtraKey: function (e) {
                if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return;
                if (e.key === Qt.Key_D) root.deviceAction(root.selected, "disconnect");
                else if (e.key === Qt.Key_X) root.deviceAction(root.selected, "remove");
                else if (e.key === Qt.Key_R) root.rescan();
                else return;
                e.accepted = true;
            }

            rowDelegate: PickerRow {
                id: rowItem
                readonly property var dev: isHeader ? null : modelData.dev || null
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
                iconColor: (rowItem.on_ || rowItem.sel) ? Theme.mauve : Theme.subtext0
                label: rowItem.isHeader ? "" : rowItem.dev ? rowItem.dev.name : rowItem.modelData.label
                trailing: rowItem.isHeader ? ""
                          : rowItem.modelData.kind === "power" ? (root.powered ? "on" : "off")
                          : rowItem.dev && rowItem.dev.connected ? "connected"
                          : rowItem.dev && !rowItem.dev.paired ? "pair" : ""
                trailingWidth: root.s(90)
                trailingColor: rowItem.on_ ? Theme.mauve : Theme.subtext0
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                text: root.status !== "" ? root.status : "enter connect · d disconnect · x forget · r rescan"
                color: root.status !== "" ? Theme.peach : Theme.surface1
                elide: Text.ElideRight
                font.pixelSize: root.s(13)
            }
        }
    }
}
