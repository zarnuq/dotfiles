.pragma library

// Pure snapshot parsing, menu data and decisions for Network.qml. Processes
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

// A tunnel, as far as NM's connection types go: openvpn imports as "vpn",
// wireguard as its own type.
function isTunnel(c) { return c.type === "vpn" || c.type === "wireguard"; }

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
        if (isTunnel(c)) {
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

// The menu's rows. Every row carries what its delegate draws — `active`,
// `label`, `icon`, `trailing` — decided here, once, when the row is built, so
// the delegate is plain bindings and no row kind is re-derived at paint time.
function buildRows(state) {
    var r = [];
    if (state.eths.length > 0) {
        r.push({ kind: "header", label: "Wired" });
        for (var e = 0; e < state.eths.length; e++) {
            var d = state.eths[e];
            var on = connOn(state.conns, d.dev);
            var up = on !== "";
            r.push({ kind: "eth", dev: d.dev, state: d.state, active: up,
                     label: up ? on : d.dev,
                     // Plugged, unplugged, or up: three states worth telling
                     // apart at a glance.
                     icon: up ? "󰈁" : d.state === "unavailable" ? "󰈂" : "󰈀",
                     trailing: up ? "connected" : d.state === "unavailable" ? "no cable" : d.state });
        }
    }
    if (state.wifiDev !== "") {
        var radio = state.radioOn;
        r.push({ kind: "header", label: "Wi-Fi — " + state.wifiDev });
        r.push({ kind: "radio", active: radio, label: "Wi-Fi " + (radio ? "on" : "off"),
                 icon: radio ? "󰤨" : "󰤮", trailing: radio ? "connected" : "" });
        if (radio)
            for (var i = 0; i < state.aps.length; i++) {
                var a = state.aps[i];
                var q = a.signal;
                r.push({ kind: "ap", ap: a, active: a.inUse, label: a.ssid,
                         icon: q >= 75 ? "󰤨" : q >= 50 ? "󰤥" : q >= 25 ? "󰤢" : "󰤟",
                         trailing: (a.security ? "󰌾 " : "") + a.signal + "%" });
            }
    }
    return r.concat(vpnRows(state.vpnConns));
}

// ── VPN ──────────────────────────────────────────────────────────────────

// The homelab tunnel is meant to be up all the time; the ~/VPNs configs are
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
    for (var i = 0; i < all.length; i++) {
        var row = all[i];
        row.label = byName[row.name] > 1
                    ? row.name + " [" + row.uuid.substring(0, 8) + "]"
                    : row.name;
        row.icon = "󰖂";
        row.trailing = vpnState(row);
    }

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

// The ~/VPNs configs NM hasn't been given yet, matched by the name NM
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
        var f = byName[c.name];
        if (!isTunnel(c) || isAlwaysOn(c.name) || !f) continue;
        var had = next[c.uuid];
        if (!had)
            next[c.uuid] = { name: c.name, file: f.file, hash: f.hash };
        // An entry recorded before hashes were: stamp the file's hash now, as
        // staleSources expects, rather than re-importing on a guess. Without
        // this an old entry was skipped here forever and never change-checked.
        else if (!had.hash && had.file === f.file && f.hash)
            next[c.uuid] = Object.assign({}, had, { hash: f.hash });
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
        if (isTunnel(conns[j]))
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
        if (!isTunnel(c)) continue;
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

// The next step of the ~/VPNs mirror, or null when NM already matches it:
// `{ remove: {uuid, name, file} }` or `{ add: <file> }`. One step at a time,
// since each is an nmcli write and they queue behind each other in the QML.
// `tried` holds its guard maps — importTried, importDone, deleteTried — keyed
// by file path and UUID respectively.
function syncStep(managed, conns, files, pending, tried) {
    // A changed file is deleted first and re-imported by the loop below;
    // an obsolete one is simply gone. Both are the same delete command.
    var obsolete = obsoleteSources(managed, conns, files)
                   .concat(staleSources(managed, conns, files));
    for (var j = 0; j < obsolete.length; j++)
        if (!tried.deleteTried[obsolete[j].uuid]) return { remove: obsolete[j] };
    for (var i = 0; i < pending.length; i++) {
        var f = pending[i];
        if (!tried.importTried[f.file] && !tried.importDone[f.file]) return { add: f };
    }
    return null;
}

// What nmcli prints for a profile's UUID. One pattern for both readers: the
// openvpn import's own shell below, and importedUuid() on its stdout.
var UUID = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";

// The UUID of the profile an import just created, or "". It comes from the
// import's own output, never a name lookup — several profiles can share a name.
function importedUuid(stdout) {
    var m = stdout.match(new RegExp("\\b" + UUID + "\\b", "i"));
    return m ? m[0] : "";
}

// How a ~/VPNs file is handed to NM. For openvpn: import, then discard the
// default route the server pushes — one command, because the second half is
// not optional.
//
// HTB pushes `default via <tun gw> metric 50`, which outranks the Wi-Fi
// default (metric 600), so every packet — DNS included — goes down a tunnel
// that carries no general internet, and the machine drops off the network the
// moment a lab connects. `never-default` discards only that default; the lab
// subnets it also pushes (10.10.x, 10.129.x, …) still get their routes. These
// are lab configs by definition, so split tunnel is the policy here.
//
// stdout is reprinted verbatim so importedUuid() still sees the UUID. `con mod`
// is avoided everywhere else in the menu (unprivileged, it drops a profile's
// stored secrets), but a profile created one line earlier has none: an openvpn
// import stores cert PATHS and `vpn.secrets` is empty.
//
// WireGuard imports are a bare `con import`, deliberately. The never-default
// fix is a `con mod`, and doing that unprivileged to a wireguard profile
// silently drops the private key it just stored — the config file is the only
// other copy, and for a peer-generated key there may be none. A wg tunnel takes
// its routes from AllowedIPs anyway; if one of yours carries 0.0.0.0/0 and you
// want it split, that is a one-off `doas nmcli con mod <uuid> ipv4.never-default yes`.
function importCommand(f) {
    if (f.kind === "wireguard")
        return ["nmcli", "connection", "import", "type", "wireguard", "file", f.file];
    return ["sh", "-c",
            "out=$(nmcli connection import type openvpn file \"$1\") || exit $?; " +
            "printf '%s\\n' \"$out\"; " +
            "uuid=$(printf '%s' \"$out\" | grep -oiE '" + UUID + "' | head -1); " +
            "[ -n \"$uuid\" ] && nmcli connection modify uuid \"$uuid\" " +
            "ipv4.never-default yes ipv6.never-default yes || true",
            "sh", f.file];
}

// How a row goes up or down. NM profiles are acted on by UUID — several
// connections may share a name, so `con up id <name>` is ambiguous.
function vpnCommand(row, up) {
    return ["nmcli", "connection", up ? "up" : "down", "uuid", row.uuid];
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
