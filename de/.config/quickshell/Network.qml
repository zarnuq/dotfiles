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
// TWO KINDS OF VPN, deliberately. The `wireguard` profile is a NetworkManager
// connection (`nmcli con up/down`), but ~/VPNs/*.ovpn are run by
// scripts/vpn-manager.sh as a bare root openvpn daemon that NM knows nothing
// about — it shows up as an "externally connected" tun0 and would vanish from
// an nmcli-only menu while still carrying traffic. So both are listed, each
// toggled the only way it can be.
//
// Nothing here elevates: `con up`/`con down`/`device wifi connect` are all
// fine unprivileged (it's `con mod` that needs doas, and would silently drop
// stored secrets without it — so this menu never modifies a profile). The
// openvpn rows shell out to vpn-manager.sh, which owns its own doas rules.
Picker {
    id: root

    ipcTarget: "network"
    allScreens: false

    readonly property string vpnScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/vpn-manager.sh"

    // The homelab tunnel is meant to be up all the time; the ~/VPNs/*.ovpn ones
    // are brought up for a HackTheBox/TryHackMe box and dropped after. They are
    // the same kind of object to nmcli, so the difference has to be stated — by
    // name, here, and nowhere else. Add or change a name and both the grouping
    // and the "it's down" warning follow.
    //
    // This is the NetworkManager CONNECTION name, which is what nmcli reports
    // and what the rows carry — not the wg-quick config in /etc/wireguard the
    // profile came from (that directory is root-only, and nothing here reads it).
    readonly property var alwaysOn: ["wireguard"]
    function isAlwaysOn(name) { return root.alwaysOn.indexOf(name) !== -1; }

    // ── state, polled only while the menu is open ────────────────────────
    property var conns: []          // [{ name, uuid, type, device, state }]
    property var aps: []            // [{ ssid, signal, security, inUse }]
    property string wifiDev: ""     // "" when this machine has no Wi-Fi at all
    property var eths: []           // [{ dev, state }] — ethernet, cable or not
    property var devStates: ({})    // device name -> NM state string
    property bool radioOn: false
    property var ovpns: []          // [{ name, file }]
    property string ovpnActive: ""  // profile name, or ""
    property string status: ""

    // Connections, devices and the radio switch: one `sh -c`, ~25ms, because
    // they are one snapshot and three separate timers would show a torn one.
    // Each line is tagged so a single parser can sort them out.
    Poll {
        id: nm
        running: root.open
        interval: 5000
        command: ["sh", "-c",
            "nmcli -t -f NAME,UUID,TYPE,DEVICE,STATE connection show | sed 's/^/C:/'; " +
            "nmcli -t -f DEVICE,TYPE,STATE device | sed 's/^/D:/'; " +
            "printf 'R:%s\\n' \"$(nmcli -t radio wifi 2>/dev/null)\""]
        onData: text => root.parseState(text)
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
        onData: text => root.parseAps(text)
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

    // The profile list and which one is up, in ONE command: as two Polls they
    // landed a tick apart, so a row could be drawn before its status arrived
    // and read as disconnected. Enter on it then asked for a connect that the
    // script — which took its answer from a marker file it never managed to
    // write — happily granted on top of the running tunnel, leaving two tun
    // devices. The script now reads the process table; this keeps the row and
    // its state from ever disagreeing in the first place.
    Poll {
        id: ovpn
        running: root.open
        interval: 5000
        command: ["sh", "-c",
            "printf 'S:%s\\n' \"$(\"" + root.vpnScript + "\" status)\"; " +
            "\"" + root.vpnScript + "\" list | sed 's/^/L:/'"]
        onData: text => root.parseOvpn(text)
    }

    function parseOvpn(text) {
        var snapshot = NetworkData.parseOvpn(text);
        root.ovpnActive = snapshot.active;
        if (snapshot.list) root.ovpns = snapshot.list; // keep the last good list
    }

    function parseState(text) {
        var snapshot = NetworkData.parseState(text);
        root.conns = snapshot.conns;
        root.wifiDev = snapshot.wifiDev;
        root.eths = snapshot.eths;
        root.devStates = snapshot.devStates;
        root.radioOn = snapshot.radioOn;
    }

    function parseAps(text) {
        var list = NetworkData.parseAps(text);
        root.aps = list;
        // Only a list with something in it ends the "scanning…" state: the
        // first tick after a rescan request usually lands before NM has any
        // results, and calling that "done" would flash an empty list as final.
        if (list.length > 0) root.scanning = false;
    }

    readonly property var vpnConns: NetworkData.vpnConnections(root.conns, root.devStates)

    rows: NetworkData.buildRows({
        conns: root.conns,
        eths: root.eths,
        wifiDev: root.wifiDev,
        radioOn: root.radioOn,
        aps: root.aps,
        vpnConns: root.vpnConns,
        ovpns: root.ovpns,
        ovpnActive: root.ovpnActive
    }, root.alwaysOn)

    // Empty unless something that should be up isn't. Shown in the bottom bar
    // whenever there's no action status competing for it.
    readonly property string warning: NetworkData.warning(root.rows, root.alwaysOn)

    function rowActive(row) {
        if (row.kind === "ap")    return row.ap.inUse;
        if (row.kind === "radio") return root.radioOn;
        if (row.kind === "eth")   return row.active;
        return row.active === true;
    }

    // Plugged, unplugged, or up: three states worth telling apart at a glance.
    function ethIcon(row) { return row.active ? "󰈁" : row.state === "unavailable" ? "󰈂" : "󰈀"; }

    /// Two profiles can share a name; NM's own convention when it has to tell
    /// its connections apart is the first 8 of the UUID, so borrow it — an
    /// unadorned pair of identical rows is unusable.
    function vpnLabel(row) {
        var n = 0;
        for (var i = 0; i < root.vpnConns.length; i++)
            if (root.vpnConns[i].name === row.name) n++;
        return n > 1 ? row.name + " [" + row.uuid.substring(0, 8) + "]" : row.name;
    }

    function rowLabel(row) {
        if (row.kind === "header") return row.label;
        if (row.kind === "radio")  return "Wi-Fi " + (root.radioOn ? "on" : "off");
        if (row.kind === "ap")     return row.ap.ssid;
        if (row.kind === "eth")    return row.name;
        if (row.kind === "nmvpn")  return root.vpnLabel(row);
        return row.name;
    }

    readonly property int headerHeight: s(28)
    readonly property int rowHeight: s(36)
    readonly property int barHeight: s(30)
    boxWidth: s(520)
    boxHeight: {
        var h = s(12) * 2 + barHeight;
        for (var i = 0; i < rows.length; i++)
            h += rows[i].kind === "header" ? headerHeight : rowHeight;
        return Math.max(h, s(140));
    }

    // ── actions ──────────────────────────────────────────────────────────
    // The menu stays open across one: joining a network takes seconds, and the
    // whole point of the status line is watching it succeed or fail.
    property string pwSsid: ""      // non-empty = asking for this SSID's key

    Process {
        id: act
        property string ssid: ""    // set when the action was an AP join
        property bool hadKey: false // ...with a password already supplied
        stderr: StdioCollector { id: actErr }
        onExited: (code) => {
            if (code === 0) {
                root.status = "";
                root.pwSsid = "";
            } else {
                var err = actErr.text.trim();
                // NM asks for secrets by failing; there is no prompt to answer
                // from a layer surface, so the box grows a password field and
                // retries. Only once — a wrong key fails the same way, and a
                // second automatic prompt would look like the first never took.
                if (act.ssid !== "" && !act.hadKey && /secret|password|psk|802-11-wireless-security/i.test(err))
                    root.pwSsid = act.ssid;
                else
                    root.status = err.split("\n")[0] || ("failed (exit " + code + ")");
            }
            nm.refresh();
            scan.refresh();      // the in-use marker moves with a join
            ovpn.refresh();
        }
    }

    function run(cmd, note, ssid, hadKey) {
        if (act.running) return;
        act.ssid = ssid || "";
        act.hadKey = hadKey === true;
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
            // `device wifi connect` reuses the saved profile for this SSID if
            // there is one, which is what keeps eduroam working: its profile is
            // named "eduroam [a8f5604d]", so matching by connection name would
            // miss it and try to create a second profile.
            root.run(["nmcli", "device", "wifi", "connect", row.ap.ssid],
                     "connecting to " + row.ap.ssid + "…", row.ap.ssid, false);
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
            if (row.active) return;
            root.run(["nmcli", "connection", "up", "uuid", row.uuid], "connecting " + row.name + "…");
        } else if (row.kind === "ovpn") {
            if (row.active) return;
            root.run([root.vpnScript, "connect", row.file], "connecting " + row.name + "…");
        }
    }

    function connectWithKey(pw) {
        if (root.pwSsid === "") return;
        // The key rides in argv, where it is readable in /proc for the life of
        // the call. nmcli has no way to take it on stdin or from a file, and
        // NM stores it itself afterwards, so this happens once per network.
        root.run(["nmcli", "device", "wifi", "connect", root.pwSsid, "password", pw],
                 "connecting to " + root.pwSsid + "…", root.pwSsid, true);
    }

    function disconnect(i) {
        if (!selectable(i)) return;
        var row = rows[i];
        if (row.kind === "eth" && row.active)
            root.run(["nmcli", "device", "disconnect", row.dev], "disconnecting " + row.dev + "…");
        else if (row.kind === "ap" && root.wifiDev !== "")
            root.run(["nmcli", "device", "disconnect", root.wifiDev], "disconnecting…");
        else if (row.kind === "nmvpn" && row.active)
            root.run(["nmcli", "connection", "down", "uuid", row.uuid], "disconnecting " + row.name + "…");
        else if (row.kind === "ovpn" && row.active)
            root.run([root.vpnScript, "disconnect"], "disconnecting " + row.name + "…");
    }

    onOpenChanged: if (!open) { root.pwSsid = ""; root.status = ""; }

    box: Component {
        Item {
            id: content
            focus: true

            function reset() {
                root.selected = root.firstSelectable();
                root.pwSsid = "";
                content.forceActiveFocus();
            }

            // Selection can outlive the list it indexed: an AP fading out of the
            // scan, or the Wi-Fi section vanishing when the radio goes off,
            // shortens `rows` under a selection that then points past the end —
            // Return would do nothing at all.
            Connections {
                target: root
                function onRowsChanged() {
                    if (!root.selectable(root.selected)) root.selected = root.firstSelectable();
                }
            }

            Keys.onPressed: function (e) {
                var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier));
                if (e.key === Qt.Key_Escape) { root.hide(); }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.activate(root.selected); }
                else if (e.key === Qt.Key_D && plain) { root.disconnect(root.selected); }
                else if (e.key === Qt.Key_R && plain) { root.rescan(); }
                else if (e.key === Qt.Key_Down || (e.key === Qt.Key_J && (plain || (e.modifiers & Qt.ControlModifier)))) root.move(1);
                else if (e.key === Qt.Key_Up   || (e.key === Qt.Key_K && (plain || (e.modifiers & Qt.ControlModifier)))) root.move(-1);
                else { return; }
                e.accepted = true;
            }

            Column {
                anchors.fill: parent
                anchors.topMargin: root.s(12)
                anchors.bottomMargin: root.s(12)
                spacing: 0

                Repeater {
                    model: root.rows

                    PickerRow {
                        id: rowItem
                        picker: root
                        readonly property bool active: !isHeader && root.rowActive(modelData)

                        width: content.width
                        headerHeight: root.headerHeight
                        rowHeight: root.rowHeight
                        current: rowItem.active
                        onActivated: root.activate(rowItem.index)

                        Row {
                            visible: !rowItem.isHeader
                            anchors.fill: parent
                            anchors.leftMargin: root.s(18)
                            anchors.rightMargin: root.s(18)
                            spacing: root.s(12)

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.s(24)
                                text: {
                                    var k = rowItem.modelData.kind;
                                    if (k === "radio") return root.radioOn ? "󰤨" : "󰤮";
                                    if (k === "eth") return root.ethIcon(rowItem.modelData);
                                    if (k === "ap") {
                                        var q = rowItem.modelData.ap.signal;
                                        return q >= 75 ? "󰤨" : q >= 50 ? "󰤥" : q >= 25 ? "󰤢" : "󰤟";
                                    }
                                    return "󰖂";
                                }
                                color: rowItem.active ? Theme.mauve : rowItem.sel ? Theme.mauve : Theme.subtext0
                                font.pixelSize: root.s(17)
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - root.s(24) - root.s(90) - parent.spacing * 2
                                elide: Text.ElideRight
                                text: rowItem.isHeader ? "" : root.rowLabel(rowItem.modelData)
                                color: rowItem.sel ? Theme.rowSelectFg : Theme.text
                                font.pixelSize: root.s(15)
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.s(90)
                                horizontalAlignment: Text.AlignRight
                                text: {
                                    var m = rowItem.modelData;
                                    if (m.kind === "ap") return (m.ap.security ? "󰌾 " : "") + m.ap.signal + "%";
                                    if (m.kind === "eth" && !rowItem.active)
                                        return m.state === "unavailable" ? "no cable" : m.state;
                                    // "external" says the tunnel is up but NM
                                    // isn't the one running it — the row is a
                                    // description of a wg-quick link, not a
                                    // profile that would come back on its own.
                                    if (rowItem.active) return m.external ? "external" : "connected";
                                    return root.isAlwaysOn(m.name) ? "down" : "";
                                }
                                color: rowItem.active ? Theme.mauve
                                       : (!rowItem.isHeader && root.isAlwaysOn(rowItem.modelData.name)) ? Theme.red
                                       : Theme.subtext0
                                font.pixelSize: root.s(13)
                            }
                        }
                    }
                }
            }

            // Bottom bar: the key prompt when one is needed, else the status
            // line, else the keys. Anchored rather than in the Column so a
            // growing list never pushes it out of the box.
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: root.s(18)
                anchors.rightMargin: root.s(18)
                height: root.barHeight

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

                    TextInput {
                        id: pw
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - root.s(160)
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: root.s(14)
                        echoMode: TextInput.Password
                        // The field appears only when NM has asked for a key, so
                        // it takes focus then and hands it back on the way out —
                        // the list's keys (d, r, j/k) are letters, and they must
                        // not eat a password being typed.
                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                        onAccepted: { root.connectWithKey(text); text = ""; }
                        Keys.onPressed: function (e) {
                            if (e.key === Qt.Key_Escape) {
                                root.pwSsid = "";
                                root.status = "";
                                content.forceActiveFocus();
                                e.accepted = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
