import Quickshell
import Quickshell.Io
import QtQuick
import "NetworkData.js" as NetworkData

// Wi-Fi + VPN menu (Super+R N / `qs ipc call network toggle`), replacing the
// floating kitty running nmtui.
//
// Built on Picker, like the audio mixer: overlay, keyboard focus and IPC come
// from there, and this file is the list, the keys and the nmcli wiring.
//
// EVERY TUNNEL IS AN NM PROFILE. The lab `~/VPNs/*.ovpn` configs used to be run
// by scripts/vpn-manager.sh as a bare root `openvpn --daemon` that NM knew
// nothing about, which meant: a `doas` rule to start one, a second `doas` rule
// to *kill* one, the profile's state scraped out of `pgrep` and /proc/<pid>/
// cmdline, and a tunnel NM reported as an "externally connected" tun0. When the
// kill rule didn't match, `disconnect` failed silently, `connect` started a
// second daemon on top, and two tunnels ran at once on two tun devices — while
// each rejected `doas` counted as a failed login until the account locked.
//
// Now they are imported (`nmcli connection import type openvpn`) and are
// ordinary NM connections, so one code path covers every row: up and down by
// UUID, state straight out of the snapshot this menu already takes. No daemon,
// no script, no doas rule, nothing to scrape. `~/VPNs` is mirrored into NM:
// `*.ovpn` imports as openvpn, `*.conf` as wireguard, a file whose contents
// changed is re-imported, and a profile whose file is gone is removed. Dropping
// a config in that directory is the whole workflow.
//
// Nothing here elevates: `con up`/`con down`/`device wifi connect` and
// `con import` are all permitted for this user (`nmcli general permissions`).
// It's `con mod` that needs doas — it would silently drop stored secrets
// without it — so this menu never modifies an existing profile.
Picker {
    id: root

    ipcTarget: "network"

    // ── state, polled only while the menu is open ────────────────────────
    property var conns: []          // [{ name, uuid, type, device, state }]
    property bool nmSeen: false     // has a real nmcli snapshot landed yet?
    property var aps: []            // [{ ssid, signal, security, inUse }]
    property string wifiDev: ""     // "" when this machine has no Wi-Fi at all
    property var eths: []           // [{ dev, state }] — ethernet, cable or not
    property var devStates: ({})    // device name -> NM state string
    property bool radioOn: false
    property bool filesSeen: false  // only successful source listings allow cleanup
    property var ovpnFiles: []      // [{name, file, hash, kind}] — ~/VPNs configs
    property string status: ""

    // Connections, devices and the radio switch: one `sh -c`, ~25ms, because
    // they are one snapshot and three separate timers would show a torn one.
    // Each line is tagged so a single parser can sort them out.
    Poll {
        id: nm
        running: root.open
        interval: 5000
        command: ["sh", "-c",
            "export LC_ALL=C; " +
            "c=$(nmcli -t -f NAME,UUID,TYPE,DEVICE,STATE connection show) || exit; " +
            "d=$(nmcli -t -f DEVICE,TYPE,STATE device) || exit; " +
            "r=$(nmcli -t radio wifi) || exit; " +
            "printf '%s\\n' \"$c\" | sed 's/^/C:/'; " +
            "printf '%s\\n' \"$d\" | sed 's/^/D:/'; " +
            "printf 'R:%s\\nS:ok\\n' \"$r\""]
        onData: text => {
            if (!text.endsWith("S:ok\n")) { root.nmSeen = false; return; }
            var snapshot = NetworkData.parseState(text);
            root.conns = snapshot.conns;
            root.wifiDev = snapshot.wifiDev;
            root.eths = snapshot.eths;
            root.devStates = snapshot.devStates;
            root.radioOn = snapshot.radioOn;
            root.nmSeen = true;
            // An action clears nmSeen and refreshes, so this is also what walks
            // several new files through import one after another.
            Qt.callLater(root.importNext);
        }
    }

    // The AP list is deliberately NOT in that command. `device wifi list`
    // defaults to `--rescan auto`, which BLOCKS for ~3.4s whenever the scan
    // cache is older than 30s (24ms when it's fresh) — and as the last command
    // in a shared `sh -c` it held back the whole snapshot with it, so an open
    // with a cold cache drew a menu with no Wi-Fi and no wired rows at all.
    // `--rescan no` reads the cache and always returns at once; asking for the
    // scan itself is what the timer below does, out of band.
    Poll {
        id: scan
        running: root.open
        interval: 5000
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list", "--rescan", "no"]
        onData: text => {
            var list = NetworkData.parseAps(text);
            root.aps = list;
            // Only a list with something in it ends the "scanning…" state: the
            // first tick after a rescan request usually lands before NM has any
            // results, and calling that "done" would flash an empty list as final.
            if (list.length > 0) root.scanning = false;
        }
    }

    // The scan request, detached: it takes seconds, nothing waits on it, and
    // the next tick of `scan` picks up whatever it found. Fired on open (a
    // menu you just opened should be looking for networks) and every 15s after.
    property bool scanning: false
    Timer {
        running: root.open && root.wifiDev !== ""
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.rescan()
    }
    function rescan() {
        if (root.wifiDev === "") return;
        root.scanning = true;
        // Fails harmlessly ("scanning not allowed immediately following
        // previous scan") if NM is already mid-scan; detached, so nobody cares.
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
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

    readonly property var vpnConns: NetworkData.vpnConnections(root.conns, root.devStates)

    rows: NetworkData.buildRows({
        conns: root.conns,
        eths: root.eths,
        wifiDev: root.wifiDev,
        radioOn: root.radioOn,
        aps: root.aps,
        vpnConns: root.vpnConns
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
    function saveSources(next) {
        root.managedVpns = next;
        vpnSources.setText(JSON.stringify(next, null, 2) + "\n");
    }
    function setSource(uuid, entry) {   // a null entry forgets the UUID
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
    readonly property var pendingImports: NetworkData.pendingImports(root.vpnConns, root.ovpnFiles)
    property var importTried: ({})
    property var importDone: ({})
    property var deleteTried: ({})

    function importNext() {
        if (!root.open || act.running || cancelVpn.running || !root.nmSeen || !root.filesSeen) return;
        var adopted = NetworkData.adoptSources(root.managedVpns, root.conns, root.ovpnFiles);
        if (JSON.stringify(adopted) !== JSON.stringify(root.managedVpns)) root.saveSources(adopted);
        var step = NetworkData.syncStep(root.managedVpns, root.conns, root.ovpnFiles, root.pendingImports,
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
    onPendingImportsChanged: Qt.callLater(root.importNext)

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
    property string pwSsid: ""      // non-empty = asking for this SSID's key

    // What the running action was, set by run() for every action, so none of
    // it can leak from one action into the next.
    Process {
        id: act
        property string vpnUuid: ""  // the `con up` in flight, which `d` can cancel
        property bool cancelling: false
        property string ssid: ""     // set when the action was an AP join
        property bool hadKey: false  // ...with a password already supplied
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
                root.clearStatus();
            } else {
                var err = actErr.text.trim();
                console.warn("Network action failed (exit " + code + "): " + err);
                // NM asks for secrets by failing; there is no prompt to answer
                // from a layer surface, so the box grows a password field and
                // retries. Only once — a wrong key fails the same way, and a
                // second automatic prompt would look like the first never took.
                if (act.ssid !== "" && !act.hadKey && /secret|password|psk|802-11-wireless-security/i.test(err))
                    root.pwSsid = act.ssid;
                else
                    root.status = err.split("\n")[0] || ("failed (exit " + code + ")");
            }
            act.vpnUuid = "";
            act.cancelling = false;
            root.nmSeen = false;
            root.filesSeen = false;
            nm.refresh();
            scan.refresh();      // the in-use marker moves with a join
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

    // `opts` says what the action is, for onExited: { ssid, hadKey } for a
    // Wi-Fi join, { importing } or { deleteUuid } for the ~/VPNs mirror.
    function run(cmd, note, opts) {
        if (act.running || cancelVpn.running) return;
        opts = opts || {};
        act.vpnUuid = cmd[1] === "connection" && cmd[2] === "up" ? cmd[4] : "";
        act.cancelling = false;
        act.ssid = opts.ssid || "";
        act.hadKey = opts.hadKey === true;
        act.importing = opts.importing || null;
        act.deleteUuid = opts.deleteUuid || "";
        root.status = note;
        act.command = cmd;
        act.running = true;
    }

    function activate(i) {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.kind === "radio") {
            root.run(["nmcli", "radio", "wifi", root.radioOn ? "off" : "on"],
                     root.radioOn ? "turning Wi-Fi off…" : "turning Wi-Fi on…");
        } else if (row.kind === "ap") {
            if (row.ap.inUse) return;             // already on it; `d` disconnects
            root.join(row.ap.ssid);
        } else if (row.kind === "eth") {
            if (row.active) return;
            // "unavailable" is NM's word for no carrier. `device connect` would
            // sit there failing on it, so say what's actually wrong instead.
            if (row.state === "unavailable") { root.status = row.dev + ": no cable"; return; }
            // `device connect` picks the device's best saved profile ("Wired
            // connection 1", or whatever autoconnect would have used) rather
            // than this menu deciding which profile an interface deserves.
            root.run(["nmcli", "device", "connect", row.dev], "connecting " + row.dev + "…");
        } else if (row.kind === "nmvpn") {
            // Enter only ever connects — `d` is the one way down, for every row
            // kind here. Toggling on Return put the always-on homelab tunnel one
            // stray keystroke from being dropped, and the two keys read the same
            // on a row whose state you weren't looking at.
            if (row.active || row.connecting) return;
            root.run(NetworkData.vpnCommand(row, true), "connecting " + row.name + "…");
        }
    }

    // `device wifi connect` reuses the saved profile for this SSID if there is
    // one, which is what keeps eduroam working: its profile is named "eduroam
    // [a8f5604d]", so matching by connection name would miss it and try to
    // create a second profile.
    function join(ssid, pw) {
        var cmd = ["nmcli", "device", "wifi", "connect", ssid];
        // The key rides in argv, where it is readable in /proc for the life of
        // the call. nmcli has no way to take it on stdin or from a file, and
        // NM stores it itself afterwards, so this happens once per network.
        if (pw !== undefined) cmd.push("password", pw);
        root.run(cmd, "connecting to " + ssid + "…", { ssid: ssid, hadKey: pw !== undefined });
    }

    function clearStatus() { root.status = ""; root.pwSsid = ""; }

    function disconnect(i) {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.kind === "eth" && row.active)
            root.run(["nmcli", "device", "disconnect", row.dev], "disconnecting " + row.dev + "…");
        else if (row.kind === "ap" && root.wifiDev !== "")
            root.run(["nmcli", "device", "disconnect", root.wifiDev], "disconnecting…");
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
        else root.clearStatus();
    }

    box: Component {
        PickerList {
            id: list
            picker: root

            onResetting: root.pwSsid = ""

            onExtraKey: function (e) {
                var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier));
                if (e.key === Qt.Key_D && plain) { root.disconnect(root.selected); }
                else if (e.key === Qt.Key_R && plain) { root.rescan(); }
                else { return; }
                e.accepted = true;
            }

            // Everything a row shows is stamped on it by NetworkData.buildRows.
            rowDelegate: PickerRow {
                id: rowItem
                readonly property bool active: modelData.active === true

                picker: root
                width: parent.width
                current: rowItem.active
                onActivated: root.activate(rowItem.index)

                icon: rowItem.isHeader ? "" : rowItem.modelData.icon
                iconColor: (rowItem.active || rowItem.sel) ? Theme.mauve : Theme.subtext0
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
                visible: root.pwSsid === ""
                text: root.status !== "" ? root.status
                      : root.warning !== "" ? root.warning
                      : (root.radioOn && root.aps.length === 0)
                        ? (root.scanning ? "scanning…" : "no networks in range")
                      : "enter connect · d disconnect · r rescan"
                color: root.status !== "" ? Theme.peach
                       : root.warning !== "" ? Theme.red : Theme.surface1
                elide: Text.ElideRight
                width: parent.width
                font.pixelSize: root.s(13)
            }

            Row {
                anchors.fill: parent
                visible: root.pwSsid !== ""
                spacing: root.s(8)

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾 " + root.pwSsid
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
                    // the list's keys (d, r, j/k) are letters, and they must
                    // not eat a password being typed.
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    onAccepted: { if (root.pwSsid !== "") root.join(root.pwSsid, text); text = ""; }
                    Keys.onPressed: function (e) {
                        if (e.key === Qt.Key_Escape) {
                            root.clearStatus();
                            list.forceActiveFocus();
                            e.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
