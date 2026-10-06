pragma ComponentBehavior: Bound
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import "NetworkData.js" as NetworkData

// Wi-Fi + VPN menu (Super+R N / `qs ipc call network toggle`), replacing the
// floating kitty running nmtui. Picker supplies overlay, focus and IPC; this
// file is the list, the keys and the wiring, NetworkData.js the logic.
//
// Devices, the radio and Wi-Fi are native Quickshell.Networking (NM over
// D-Bus): live, and scanned only while the menu is open. The module has no VPN
// support, so the tunnels — and the ~/VPNs mirror below — still go through nmcli.
//
// Every tunnel is an NM profile, up and down by UUID — `~/VPNs` is mirrored
// into NM (`*.ovpn` → openvpn, `*.conf` → wireguard; changed files re-import,
// vanished ones are removed). Nothing here elevates: `con up`/`con down`/
// `con import` are permitted unprivileged. `con mod`
// would silently drop stored secrets without doas, so this menu never
// modifies an existing profile. History and routing notes: CLAUDE.md.
Picker {
    id: root

    ipcTarget: "network"

    // ── state ────────────────────────────────────────────────────────────
    readonly property var devices: Networking.devices.values
    readonly property WifiDevice wifi: root.devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property bool radioOn: Networking.wifiEnabled

    Binding {
        when: root.wifi !== null
        target: root.wifi
        property: "scannerEnabled"
        value: root.open && root.radioOn
    }

    // One row per SSID (NM already groups the APs), connected first, then by
    // signal. A hidden network has no name and nothing to click.
    readonly property var aps: {
        if (!root.wifi) return [];
        return root.wifi.networks.values.filter(n => n.name !== "").map(n => ({
            net: n, ssid: n.name, signal: Math.round(n.signalStrength * 100),
            security: n.security !== WifiSecurityType.Open, inUse: n.connected
        })).sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal));
    }

    readonly property var eths: root.devices.filter(d => d.type === DeviceType.Wired).map(d => ({
        dev: d.name, device: d, noCable: !d.hasLink, connected: d.connected
    }))

    // VPN state from nmcli, polled only while the menu is open: connections,
    // plus device states (a wg-quick link shows as "connected (externally)").
    property var conns: []          // [{ name, uuid, type, device, state }]
    property var devStates: ({})    // device name -> NM state string
    property bool nmSeen: false     // has a real nmcli snapshot landed yet?
    property bool filesSeen: false  // only successful source listings allow cleanup
    property var ovpnFiles: []      // [{name, file, hash, kind}] — ~/VPNs configs
    property string status: ""

    Poll {
        id: nm
        running: root.open
        interval: 5000
        command: ["sh", "-c",
            "export LC_ALL=C; " +
            "c=$(nmcli -t -f NAME,UUID,TYPE,DEVICE,STATE connection show) || exit; " +
            "d=$(nmcli -t -f DEVICE,TYPE,STATE device) || exit; " +
            "printf '%s\\n' \"$c\" | sed 's/^/C:/'; " +
            "printf '%s\\n' \"$d\" | sed 's/^/D:/'; " +
            "printf 'S:ok\\n'"]
        onData: text => {
            if (!text.endsWith("S:ok\n")) { root.nmSeen = false; return; }
            var snapshot = NetworkData.parseState(text);
            root.conns = snapshot.conns;
            root.devStates = snapshot.devStates;
            root.nmSeen = true;
            // An action clears nmSeen and refreshes, so this is also what walks
            // several new files through import one after another.
            Qt.callLater(root.importNext);
        }
    }

    // Lab configs on disk. Their *state* comes from the nmcli snapshot like
    // everything else — this only answers "is there a file here NM hasn't been
    // given yet", so it can be a plain listing on the same beat.
    Poll {
        id: ovpn
        running: root.open
        interval: 5000
        command: ["sh", "-c",
            "dir=\"$HOME/VPNs\"; " +
            "if [ -e \"$dir\" ]; then [ -d \"$dir\" ] && [ -r \"$dir\" ] && [ -x \"$dir\" ] || exit 1; fi; " +
            "for f in \"$dir\"/*.ovpn \"$dir\"/*.conf; do [ -f \"$f\" ] && sha256sum \"$f\"; done; " +
            "printf 'F:ok\\n'"]
        onData: text => {
            if (!text.endsWith("F:ok\n")) { root.filesSeen = false; return; }
            root.ovpnFiles = NetworkData.parseVpnFiles(text);
            root.filesSeen = true;
            Qt.callLater(root.importNext);
        }
    }

    rows: NetworkData.buildRows({
        conns: root.conns,
        devStates: root.devStates,
        eths: root.eths,
        wifiDev: root.wifi ? root.wifi.name : "",
        radioOn: root.radioOn,
        aps: root.aps
    })

    // Remember exact UUIDs and source paths across restarts. Existing OpenVPN
    // profiles are adopted only while a matching source file exists; unrelated
    // VPNs and WireGuard profiles never become cleanup candidates.
    FileView {
        id: vpnSources
        path: Config.stateDir + "/vpn-sources.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
    property var managedVpns: {
        try {
            var parsed = JSON.parse(vpnSources.text() || "{}");
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed;
        } catch (e) { console.warn("Ignoring invalid VPN source registry: " + e); }
        return ({});
    }
    function saveSources(next): void {
        root.managedVpns = next;
        vpnSources.setText(JSON.stringify(next, null, 2) + "\n");
    }
    function setSource(uuid, entry): void {   // a null entry forgets the UUID
        var next = Object.assign({}, root.managedVpns);
        if (entry) next[uuid] = entry; else delete next[uuid];
        root.saveSources(next);
    }

    // The mirror's guards, each answering a different question. importTried
    // (cleared on open, like its twin deleteTried): a file NM refuses is not
    // retried every tick, but gets another go on the next open. importDone
    // (never cleared): a finished import stays done while the snapshot that
    // would vouch for it is still a refresh away. nmSeen/filesSeen: nothing is
    // imported or removed before both listings have actually landed.
    property var importTried: ({})
    property var importDone: ({})
    property var deleteTried: ({})

    function importNext(): void {
        if (!root.open || act.running || cancelVpn.running || !root.nmSeen || !root.filesSeen) return;
        var adopted = NetworkData.adoptSources(root.managedVpns, root.conns, root.ovpnFiles);
        if (JSON.stringify(adopted) !== JSON.stringify(root.managedVpns)) root.saveSources(adopted);
        var step = NetworkData.syncStep(root.managedVpns, root.conns, root.ovpnFiles,
                                        { importTried: root.importTried, importDone: root.importDone,
                                          deleteTried: root.deleteTried });
        if (step && step.remove) {
            root.deleteTried[step.remove.uuid] = true;
            root.run(["nmcli", "connection", "delete", "uuid", step.remove.uuid],
                     "removing " + step.remove.name + "…", { deleteUuid: step.remove.uuid });
        } else if (step) {
            root.importTried[step.add.file] = true;
            root.run(NetworkData.importCommand(step.add), "importing " + step.add.name + "…",
                     { importing: step.add });
        }
    }

    // Empty unless something that should be up isn't. Shown in the bottom bar
    // whenever there's no action status competing for it.
    readonly property string warning: NetworkData.warning(root.rows)

    rowHeight: s(36)
    barHeight: s(30)
    minBoxHeight: s(140)
    boxWidth: s(520)

    // ── actions ──────────────────────────────────────────────────────────
    // The menu stays open across one: joining a network takes seconds, and the
    // whole point of the status line is watching it succeed or fail.
    // A Wi-Fi join in flight. NM asks for secrets by failing with NoSecrets;
    // there is no prompt to answer from a layer surface, so the box grows a
    // password field and retries. Only once — a wrong key fails the same way,
    // and a second automatic prompt would look like the first never took.
    property WifiNetwork joining: null
    property bool joinHadKey: false
    property bool askingKey: false  // the bottom bar is a password field for `joining`
    Connections {
        target: root.joining
        function onConnectionFailed(reason): void {
            var n = root.joining;
            var psk = [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].indexOf(n.security) !== -1;
            if (reason === ConnectionFailReason.NoSecrets && !root.joinHadKey && psk) {
                root.status = "";
                root.askingKey = true;
                return;
            }
            root.joining = null;
            root.status = n.name + ": " + ConnectionFailReason.toString(reason);
        }
        function onConnectedChanged(): void {
            if (!root.joining.connected) return;
            root.cancelJoin();
        }
    }

    // What the running action was, set by run() for every action, so none of
    // it can leak from one action into the next.
    Process {
        id: act
        property string vpnUuid: ""  // the `con up` in flight, which `d` can cancel
        property bool cancelling: false
        property var importing: null // the ~/VPNs file, when it was an auto-import
        property string deleteUuid: ""
        stdout: StdioCollector { id: actOut }
        stderr: StdioCollector { id: actErr }
        onExited: (code) => {
            var f = act.importing;
            if (code === 0 && f) {
                // Remember a successful import for good; the snapshot that
                // would otherwise vouch for it is still a refresh away.
                root.importDone[f.file] = true;
                var uuid = NetworkData.importedUuid(actOut.text);
                // Record WHAT was imported, not just where it came from: a file
                // replaced under the same name is invisible to a name check.
                if (uuid !== "") root.setSource(uuid, { name: f.name, file: f.file, hash: f.hash });
            }
            if (code === 0 && act.deleteUuid !== "") {
                var old = root.managedVpns[act.deleteUuid];
                if (old) { delete root.importDone[old.file]; delete root.importTried[old.file]; }
                root.setSource(act.deleteUuid, null);
            }
            if (code === 0 || act.cancelling) {
                root.status = "";
            } else {
                var err = actErr.text.trim();
                console.warn("Network action failed (exit " + code + "): " + err);
                root.status = err.split("\n")[0] || ("failed (exit " + code + ")");
            }
            act.vpnUuid = "";
            act.cancelling = false;
            root.nmSeen = false;
            root.filesSeen = false;
            nm.refresh();
            ovpn.refresh();
        }
    }

    // A pending `con up` owns act until it finishes. Cancelling it needs a
    // second process: killing nmcli itself would leave NM trying to connect.
    Process {
        id: cancelVpn
        stderr: StdioCollector { id: cancelErr }
        onExited: code => {
            if (code !== 0) {
                act.cancelling = false;
                root.status = cancelErr.text.trim().split("\n")[0] || "VPN cancellation failed";
                console.warn(root.status);
            }
            nm.refresh();
            Qt.callLater(root.importNext);
        }
    }

    // `opts` says what the action is, for onExited: { vpnUuid } for a VPN
    // `con up` (the one `d` can cancel), { importing } or { deleteUuid } for
    // the ~/VPNs mirror.
    function run(cmd, note, opts): void {
        if (act.running || cancelVpn.running) return;
        opts = opts || {};
        act.vpnUuid = opts.vpnUuid || "";
        act.cancelling = false;
        act.importing = opts.importing || null;
        act.deleteUuid = opts.deleteUuid || "";
        root.status = note;
        act.command = cmd;
        act.running = true;
    }

    function activate(i): void {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.kind === "radio") {
            Networking.wifiEnabled = !root.radioOn;
        } else if (row.kind === "ap") {
            if (row.ap.inUse) return;             // already on it; `d` disconnects
            root.join(row.ap.net);
        } else if (row.kind === "eth") {
            if (row.active) return;
            // Connecting a device with no carrier would sit there failing, so
            // say what's actually wrong instead.
            if (row.noCable || !row.device.network) { root.status = row.dev + ": no cable"; return; }
            // The wired network activates the device's best saved profile
            // ("Wired connection 1", or whatever autoconnect would have used)
            // rather than this menu deciding which one an interface deserves.
            row.device.network.connect();
        } else if (row.kind === "nmvpn") {
            // Enter only ever connects — `d` is the one way down, for every row
            // kind here. Toggling on Return put the always-on homelab tunnel one
            // stray keystroke from being dropped, and the two keys read the same
            // on a row whose state you weren't looking at.
            if (row.active || row.connecting) return;
            root.run(NetworkData.vpnCommand(row, true), "connecting " + row.name + "…",
                     { vpnUuid: row.uuid });
        }
    }

    // connect() reuses the saved profile for this SSID if there is one, which
    // is what keeps eduroam working (its profile is named "eduroam [a8f5604d]").
    function join(net, pw): void {
        root.joining = net;
        root.joinHadKey = pw !== undefined;
        root.askingKey = false;
        root.status = "connecting to " + net.name + "…";
        if (pw === undefined) net.connect(); else net.connectWithPsk(pw);
    }

    function cancelJoin(): void { root.joining = null; root.askingKey = false; root.status = ""; }

    function disconnect(i): void {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.kind === "eth" && row.active)
            row.device.disconnect();
        else if (row.kind === "ap" && root.wifi)
            root.wifi.disconnect();
        else if (row.kind === "nmvpn" && (row.active || row.connecting || act.vpnUuid === row.uuid)) {
            if (act.running && act.vpnUuid === row.uuid && !cancelVpn.running) {
                act.cancelling = true;
                root.status = "cancelling " + row.name + "…";
                cancelVpn.command = NetworkData.vpnCommand(row, false);
                cancelVpn.running = true;
            } else if (!act.running) {
                root.run(NetworkData.vpnCommand(row, false), "disconnecting " + row.name + "…");
            }
        }
    }

    onOpenChanged: {
        if (open) {
            root.nmSeen = false;
            root.filesSeen = false;
            root.importTried = ({});
            root.deleteTried = ({});
        }
        else root.cancelJoin();
    }

    box: Component {
        PickerList {
            id: list
            picker: root

            onResetting: root.askingKey = false

            onExtraKey: function (e) {
                var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier));
                if (e.key === Qt.Key_D && plain) { root.disconnect(root.selected); }
                else { return; }
                e.accepted = true;
            }

            // Everything a row shows is stamped on it by NetworkData.buildRows.
            rowDelegate: PickerRow {
                id: rowItem
                readonly property bool active: rowItem.modelData.active === true

                picker: root
                width: parent.width
                current: rowItem.active
                onActivated: root.activate(rowItem.index)

                icon: rowItem.isHeader ? "" : rowItem.modelData.icon
                label: rowItem.isHeader ? "" : rowItem.modelData.label
                trailing: rowItem.isHeader ? "" : rowItem.modelData.trailing
                trailingWidth: root.s(90)
                // A tunnel that was supposed to stay up and isn't reads red.
                trailingColor: rowItem.active ? Theme.mauve
                               : rowItem.modelData.alwaysOn === true ? Theme.red
                               : Theme.subtext0
            }

            // Bottom bar: the key prompt when one is needed, else the status
            // line, else the keys.
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.askingKey
                text: root.status !== "" ? root.status
                      : root.warning !== "" ? root.warning
                      : (root.radioOn && root.aps.length === 0) ? "scanning…"
                      : "enter connect · d disconnect"
                color: root.status !== "" ? Theme.peach
                       : root.warning !== "" ? Theme.red : Theme.surface1
                elide: Text.ElideRight
                width: parent.width
                font.pixelSize: root.s(13)
            }

            Row {
                anchors.fill: parent
                visible: root.askingKey
                spacing: root.s(8)

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾 " + (root.joining ? root.joining.name : "")
                    color: Theme.mauve
                    font.pixelSize: root.s(13)
                }

                Field {
                    id: pw
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - root.s(160)
                    font.pixelSize: root.s(14)
                    echoMode: TextInput.Password
                    // The field appears only when NM has asked for a key, so
                    // it takes focus then and hands it back on the way out —
                    // the list's keys (d, j/k) are letters, and they must
                    // not eat a password being typed.
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    onAccepted: { if (root.joining) root.join(root.joining, text); text = ""; }
                    Keys.onPressed: function (e) {
                        if (e.key === Qt.Key_Escape) {
                            root.cancelJoin();
                            list.forceActiveFocus();
                            e.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
