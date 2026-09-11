.pragma library

// Pure snapshot parsing and menu data. Processes and mutable state belong to
// Network.qml; keeping inputs explicit also keeps its QML bindings reactive.

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

function parseOvpn(text) {
    var lines = text.split("\n");
    var active = "", list = null;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.substring(0, 2) === "S:") active = line.substring(2).trim();
        else if (line.substring(0, 2) === "L:") {
            try { list = JSON.parse(line.substring(2)); } catch (e) { list = null; }
        }
    }
    // A null list lets the caller retain the last good list independently of
    // the active profile, whose absence still means the tunnel is down.
    return { active: active, list: list };
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
                       external: st !== undefined && st.indexOf("external") !== -1 });
        }
    }
    return out;
}

function buildRows(state, alwaysOn) {
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
    // Group both VPN kinds by purpose, while preserving the kind and identity
    // the caller needs to choose the correct connect/disconnect command.
    var all = [];
    var v = state.vpnConns;
    for (var j = 0; j < v.length; j++)
        all.push({ kind: "nmvpn", name: v[j].name, uuid: v[j].uuid, active: v[j].active,
                   external: v[j].external });
    for (var m = 0; m < state.ovpns.length; m++)
        all.push({ kind: "ovpn", name: state.ovpns[m].name, file: state.ovpns[m].file,
                   active: state.ovpns[m].name === state.ovpnActive });

    function section(title, pick) {
        var any = false;
        for (var i = 0; i < all.length; i++) {
            if (pick(all[i].name) !== true) continue;
            if (!any) { r.push({ kind: "header", label: title }); any = true; }
            r.push(all[i]);
        }
    }
    section("Homelab", function (n) { return alwaysOn.indexOf(n) !== -1; });
    section("Labs",    function (n) { return alwaysOn.indexOf(n) === -1; });
    return r;
}

function warning(rows, alwaysOn) {
    for (var a = 0; a < alwaysOn.length; a++) {
        var name = alwaysOn[a], seen = false, up = false;
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i];
            if (row.kind === "header" || row.name !== name) continue;
            seen = true;
            if (row.active === true) up = true;
        }
        // Duplicate profiles can share a name: any active one means the
        // tunnel is up, even when the first matching row is disconnected.
        if (seen && !up) return name + " is down — enter to reconnect";
    }
    return "";
}
