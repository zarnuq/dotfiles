.pragma library

// Parsing and filtering for the keybind cheatsheet (Keybinds.qml). Kept out of
// the QML so tests/quickshell/tst_keybinds.qml can load it: the test runner
// can't import Quickshell.
//
// A flat line scan of reach's config.zon, not a ZON parse, in the same style as
// launcher/Commands.qml. Only the `.binds` block is read. A `//` comment directly
// in that block becomes a section header (consecutive comment lines join), a
// `.chord` opens a section of its own, and every `.key` line becomes a row.

// Compiled into reach and never listed in config.zon (see reach/CLAUDE.md).
var DESKTOP_ROWS = [
    { kind: "header", label: "desktops (built in)" },
    { kind: "bind", key: "Super+1–9", action: "view desktop" },
    { kind: "bind", key: "Super+Ctrl+1–9", action: "toggle desktop" },
    { kind: "bind", key: "Super+Shift+1–9", action: "move window to desktop" }
];

/// config.zon writes keys the way river names them; this is what a human reads.
function pretty(k) {
    if (k.indexOf("XF86Audio") === 0) return k.slice(9) + " key";
    var parts = k.split("+");
    for (var i = 0; i < parts.length; i++)
        parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
    return parts.join("+");
}

/// The right-hand side of a bind line, made readable.
function action(line) {
    var m = /\.action\s*=\s*(.*)$/.exec(line);
    if (!m) return "";
    var spawn = /\.spawn\s*=\s*"((?:[^"\\]|\\.)*)"/.exec(m[1]);
    if (spawn) {
        var s = spawn[1];
        var ipc = /^qs ipc call (.*)$/.exec(s);
        if (ipc) return ipc[1];
        return s.replace(/^exec\s+/, "")
                .replace(/\s+\d*[<>].*$/, "")          // shell redirections
                .replace(/\S*\/(\S+)/g, "$1");          // paths → basenames
    }
    // `.{ .move = .{ .x = -40 } } },` → "move x -40". A dot is syntax only
    // before a name or brace, so `-0.05` survives.
    return m[1].replace(/\.(?=[A-Za-z_{])/g, " ")
               .replace(/[{}=,]/g, " ")
               .replace(/\s+/g, " ")
               .trim();
}

/// [{ kind: "header", label } | { kind: "bind", key, action }]
function parse(text) {
    var out = [];
    var lines = (text || "").split("\n");
    var depth = 0, bindsDepth = -1, chord = "", chordDepth = -1, prevComment = false;

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var isComment = false;

        if (bindsDepth < 0) {
            if (/^\s*\.binds\s*=/.test(line)) bindsDepth = depth;
        } else {
            var comment = /^\s*\/\/\s*(.*)$/.exec(line);
            var key = /\.key\s*=\s*"([^"]+)"/.exec(line);
            if (comment && depth === bindsDepth + 1) {
                isComment = true;
                if (prevComment) out[out.length - 1].label += " " + comment[1];
                else out.push({ kind: "header", label: comment[1] });
            } else if (key && /\.chord\s*=/.test(line)) {
                chord = key[1];
                chordDepth = depth;
                out.push({ kind: "header", label: pretty(chord) + ", then" });
            } else if (key) {
                out.push({ kind: "bind",
                           key: chordDepth >= 0 ? pretty(chord) + "  " + key[1] : pretty(key[1]),
                           action: action(line) });
            }
        }
        prevComment = isComment;

        for (var c = 0; c < line.length; c++) {
            if (line[c] === "{") depth++;
            else if (line[c] === "}") {
                depth--;
                if (chordDepth >= 0 && depth <= chordDepth) { chordDepth = -1; chord = ""; }
                if (bindsDepth >= 0 && depth <= bindsDepth) return out.concat(DESKTOP_ROWS);
            }
        }
    }
    // No .binds block: reach runs its compiled-in keymap, which isn't listed.
    return out.length ? out.concat(DESKTOP_ROWS) : [];
}

/// Rows whose key or action contains the query, under their section header.
/// A query matching a header keeps its whole section.
function filter(rows, query) {
    var q = (query || "").toLowerCase().trim();
    var out = [], header = null, headerHit = q === "";
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        if (r.kind === "header") {
            header = r;
            headerHit = q === "" || r.label.toLowerCase().indexOf(q) >= 0;
            continue;
        }
        if (!headerHit && (r.key + " " + r.action).toLowerCase().indexOf(q) < 0) continue;
        if (header) { out.push(header); header = null; }
        out.push(r);
    }
    return out;
}
