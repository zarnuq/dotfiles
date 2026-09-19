.pragma library

// Pure snapshot parsing and menu data for Network.qml and Vpn.qml. Processes
// and mutable state belong to the QML; keeping inputs explicit also keeps its
// bindings reactive.

// nmcli escapes ':' as '\:' and '\' as '\\' in its terse output.
function tsplit(line) {
    var out = [], cur = "";
    for (var i = 0; i < line.length; i++) {
        var c = line.charAt(i);
        if (c === "\\" && i + 1 < line.length) cur += line.charAt(++i);
        else if (c === ":") { out.push(cur); cur = ""; }
        else cur += c;
    }
    out.push(cur);
    return out;
}

function parseState(text) {
    var lines = text.split("\n");
    var conns = [], dev = "", radio = false, eths = [], devStates = {};

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.length < 2) continue;
        var tag = line.substring(0, 2);
        var f = tsplit(line.substring(2));

        if (tag === "C:") {
            // UUID is the identity: NM permits several connections with the
            // same name, and activating by name could select the wrong one.
            conns.push({ name: f[0], uuid: f[1], type: f[2], device: f[3], state: f[4] });
        } else if (tag === "D:") {
            devStates[f[0]] = f[2];
            if (f[1] === "wifi" && dev === "") dev = f[0];
            // Keep unavailable wired devices so the menu can say "no cable".
            else if (f[1] === "ethernet") eths.push({ dev: f[0], state: f[2] });
        } else if (tag === "R:") {
            radio = line.substring(2) === "enabled";
        }
    }

    return { conns: conns, wifiDev: dev, eths: eths, devStates: devStates, radioOn: radio };
}

function parseAps(text) {
    var lines = text.split("\n");
    var aps = {};
    for (var i = 0; i < lines.length; i++) {
        if (lines[i] === "") continue;
        var f = tsplit(lines[i]);
        var ssid = f[3];
        if (!ssid) continue;              // hidden network: nothing to click
        var sig = parseInt(f[1]) || 0;
        // Keep the strongest AP per SSID without losing a weaker AP's in-use
        // marker. The same SSID can appear on several bands or access points.
        var prev = aps[ssid];
        if (!prev || sig > prev.signal)
            aps[ssid] = { ssid: ssid, signal: sig, security: f[2],
                          inUse: (f[0] === "*") || (prev ? prev.inUse : false) };
        else if (f[0] === "*") prev.inUse = true;
    }

    var list = [];
    for (var k in aps) list.push(aps[k]);
    list.sort(function (a, b) {
        if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
        return b.signal - a.signal;
    });
    return list;
}

// ~/VPNs configs as `sha256sum` prints them — "<hash>  <path>" — into
// [{name, file, hash, kind}]. The name is what NM will call the profile, which
// is how an already-imported file is recognised; the hash is how a file that was
// REPLACED under the same name is recognised, which name matching alone cannot
// see. `.ovpn` is openvpn, `.conf` is wireguard — the two NM import types.
function parseVpnFiles(text) {
    var out = [], lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^([0-9a-f]{64})\s\s?(.+)$/);
        if (!m) continue;
        var path = m[2];
        var base = path.substring(path.lastIndexOf("/") + 1);
        var wg = /\.conf$/.test(base);
        out.push({ name: base.replace(/\.(ovpn|conf)$/, ""), file: path, hash: m[1],
                   kind: wg ? "wireguard" : "openvpn" });
    }
    return out;
}

// Name of the connection currently active on a device, or "".
function connOn(conns, device) {
    for (var i = 0; i < conns.length; i++) {
        var c = conns[i];
        if (c.device === device && c.state === "activated") return c.name;
    }
    return "";
}

function vpnConnections(conns, devStates) {
    var out = [];
    for (var i = 0; i < conns.length; i++) {
        var c = conns[i];
        if (c.type === "vpn" || c.type === "wireguard") {
            // NM describes wg-quick links through volatile profiles. It marks
            // the DEVICE as "connected (externally)", not the connection.
            var st = devStates[c.device];
            out.push({ name: c.name, uuid: c.uuid, active: c.state === "activated",
                       connecting: c.state === "activating",
                       external: st !== undefined && st.indexOf("external") !== -1 });
        }
    }
    return out;
}

function buildRows(state) {
    var r = [];
    if (state.eths.length > 0) {
        r.push({ kind: "header", label: "Wired" });
        for (var e = 0; e < state.eths.length; e++) {
            var d = state.eths[e];
            var on = connOn(state.conns, d.dev);
            r.push({ kind: "eth", dev: d.dev, state: d.state,
                     name: on !== "" ? on : d.dev, active: on !== "" });
        }
    }
    if (state.wifiDev !== "") {
        r.push({ kind: "header", label: "Wi-Fi — " + state.wifiDev });
        r.push({ kind: "radio" });
        if (state.radioOn)
            for (var i = 0; i < state.aps.length; i++)
                r.push({ kind: "ap", ap: state.aps[i] });
    }
    return r.concat(vpnRows(state.vpnConns));
}

// ── VPN ──────────────────────────────────────────────────────────────────
// Everything below is shared by the network menu, where the tunnels are one
// section among the Wi-Fi and wired rows, and the VPN menu, which is that
// section on its own. Both list the same two kinds of tunnel and must agree
// about them: a row grouped one way here and another way there, or brought up
// by a different command, is the same tunnel behaving differently depending on
// which menu you happened to open.

// The homelab tunnel is meant to be up all the time; the ~/VPNs/*.ovpn ones are
// brought up for a HackTheBox/TryHackMe box and dropped after. They are now the
// same kind of object to nmcli — both are NM profiles — so the difference has to
// be stated here, and nowhere else. Add a name and both the grouping and the
// "it's down" warning follow.
//
// This is the NetworkManager CONNECTION name, which is what nmcli reports and
// what the rows carry — not the wg-quick config in /etc/wireguard the profile
// came from (that directory is root-only, and nothing here reads it).
var ALWAYS_ON = ["wireguard"];

function isAlwaysOn(name) { return ALWAYS_ON.indexOf(name) !== -1; }

// Every tunnel NM knows about, grouped by purpose. Each row carries everything
// the menu needs to draw and act on it: its `label`, whether it is `alwaysOn`,
// and the identity its command is built from. Those two are stamped here rather
// than asked later, because both are decided exactly once — when the row is
// built — and a delegate that re-derives them per frame has to be handed the
// whole list to do it. `warning()` below is the other reason: matching an
// always-on tunnel by NAME across every row would count a wired connection
// called "wireguard" as the homelab tunnel.
function vpnRows(vpnConns) {
    var all = [], byName = {};
    for (var j = 0; j < vpnConns.length; j++) {
        var c = vpnConns[j];
        byName[c.name] = (byName[c.name] || 0) + 1;
        all.push({ kind: "nmvpn", name: c.name, uuid: c.uuid, active: c.active,
                   connecting: c.connecting === true,
                   external: c.external, alwaysOn: isAlwaysOn(c.name) });
    }

    // Two NM profiles can share a name; NM's own convention when it has to tell
    // its connections apart is the first 8 of the UUID, so borrow it — an
    // unadorned pair of identical rows is unusable.
    for (var i = 0; i < all.length; i++)
        all[i].label = (all[i].kind === "nmvpn" && byName[all[i].name] > 1)
                       ? all[i].name + " [" + all[i].uuid.substring(0, 8) + "]"
                       : all[i].name;

    var r = [];
    function section(title, wanted) {
        var any = false;
        for (var k = 0; k < all.length; k++) {
            if (all[k].alwaysOn !== wanted) continue;
            if (!any) { r.push({ kind: "header", label: title }); any = true; }
            r.push(all[k]);
        }
    }
    section("Homelab", true);
    section("Labs", false);
    return r;
}

// The ~/VPNs/*.ovpn files NM hasn't been given yet, matched by the name NM
// would give the profile. Matching this way is what stops a re-import on every
// tick — `con import` would happily create a duplicate profile each time.
function pendingImports(vpnConns, ovpnFiles) {
    var known = {}, out = [];
    for (var i = 0; i < vpnConns.length; i++) known[vpnConns[i].name] = true;
    for (var m = 0; m < (ovpnFiles || []).length; m++)
        if (!known[ovpnFiles[m].name]) out.push(ovpnFiles[m]);
    return out;
}

// The VPN section is a MIRROR of ~/VPNs (plus the always-on tunnels): a file
// with no profile gets imported, a profile with no file gets deleted. Both
// halves are gated on a listing that actually succeeded — `filesSeen` — so an
// unreadable ~/VPNs never reads as "delete everything".
function adoptSources(managed, conns, files) {
    var next = Object.assign({}, managed), byName = {};
    for (var i = 0; i < files.length; i++) byName[files[i].name] = files[i];
    for (var j = 0; j < conns.length; j++) {
        var c = conns[j];
        if ((c.type === "vpn" || c.type === "wireguard") && !isAlwaysOn(c.name)
            && byName[c.name] && !next[c.uuid])
            next[c.uuid] = { name: c.name, file: byName[c.name].file, hash: byName[c.name].hash };
    }
    return next;
}

// Profiles whose source file still exists but has CHANGED since it was
// imported. HTB reissues a config under the same filename — new server, new
// certs — so matching by name alone keeps serving the old profile forever: the
// file said dedivip-4 while the profile still said dedivip-3, every connection
// timed out, and the same file worked fine from a terminal. Deleting the stale
// profile frees the name, and the ordinary import path recreates it.
function staleSources(managed, conns, files) {
    var byFile = {}, live = {}, out = [];
    for (var i = 0; i < files.length; i++) byFile[files[i].file] = files[i].hash;
    for (var j = 0; j < conns.length; j++)
        if (conns[j].type === "vpn" || conns[j].type === "wireguard")
            live[conns[j].uuid] = conns[j].name;
    for (var uuid in managed) {
        var s = managed[uuid];
        if (!s || !live[uuid] || isAlwaysOn(live[uuid])) continue;
        var now = byFile[s.file];
        // No stored hash means the entry predates this check; adoptSources
        // stamps one on the next pass rather than re-importing on a guess.
        if (now && s.hash && now !== s.hash)
            out.push({ uuid: uuid, name: s.name, file: s.file });
    }
    return out;
}

function obsoleteSources(managed, conns, files) {
    var presentFile = {}, presentName = {}, out = [];
    for (var i = 0; i < files.length; i++) {
        presentFile[files[i].file] = true;
        presentName[files[i].name] = true;
    }
    for (var j = 0; j < conns.length; j++) {
        var c = conns[j];
        if (isAlwaysOn(c.name)) continue;          // never ours to remove
        if (c.type !== "vpn" && c.type !== "wireguard") continue;
        var source = managed[c.uuid];
        if (source && typeof source.file === "string") {
            // Imported from a file this registry remembers, and that file is gone.
            if (!presentFile[source.file]) out.push({ uuid: c.uuid, name: c.name, file: source.file });
        } else if (c.type === "vpn" && !presentName[c.name]) {
            // Untracked, and no file would produce its name. Only OpenVPN:
            // that profile can be rebuilt from a file, whereas an untracked
            // WireGuard profile holds a private key nothing else has a copy of,
            // so it is left alone however it got here.
            out.push({ uuid: c.uuid, name: c.name, file: "" });
        }
    }
    return out;
}

// How a row goes up or down. NM profiles are acted on by UUID — several
// connections may share a name, so `con up id <name>` is ambiguous.
function vpnCommand(row, up) {
    if (row.kind === "nmvpn") return ["nmcli", "connection", up ? "up" : "down", "uuid", row.uuid];
    return null;
}

// What a row's right-hand column says about its state. "external" means the
// tunnel is up but NM isn't the one running it — the row is a description of a
// wg-quick link, not a profile that would come back on its own.
function vpnState(row) {
    if (row.connecting === true) return "connecting…";
    if (row.active === true) return row.external ? "external" : "connected";
    return row.alwaysOn ? "down" : "";
}

// Empty unless something that should be up isn't. Duplicate profiles can share
// a name, so any active one means that tunnel is up.
function warning(rows) {
    var up = {};
    for (var i = 0; i < rows.length; i++)
        if (rows[i].alwaysOn === true)
            up[rows[i].name] = up[rows[i].name] === true || rows[i].active === true;
    for (var name in up)
        if (!up[name]) return name + " is down — enter to reconnect";
    return "";
}
