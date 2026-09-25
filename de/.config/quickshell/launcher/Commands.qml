pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io

// The catalogue behind the launcher's ">" mode: every menu the shell can put on
// screen, plus the handful of actions that have no surface of their own.
//
// Why a catalogue and not a listing: `qs ipc show` already enumerates every
// target, and parsing it would stay in sync for free — but it yields
// "wallpaperpicker / toggle", not "Wallpaper picker / thumbnail grid". A
// palette is exactly the place where the label and the one-line gloss are the
// content, so they are written once, here, next to the target they name.
//
// Shaped like the other two launcher row types: `name` is what the row draws
// and what the query matches, `desc` is the dimmed right-hand label file mode
// uses for the parent directory.
Singleton {
    id: root

    // `open`, never `toggle`: picking "Music" out of a list must put the music
    // window up, and toggle would take it down whenever it was already there.
    // Picker and Music both expose `open` for this (`show` is unusable — the
    // CLI eats `qs ipc call <target> show` as its own `qs ipc show`).
    readonly property var catalogue: [
        { name: "Network",          desc: "Wi-Fi + VPN",         glyph: "󰤨", args: ["network",         "open"] },
        { name: "Clipboard",        desc: "history picker",      glyph: "󰅍", args: ["clipboard",       "open"] },
        { name: "Audio",            desc: "sinks + mixer",       glyph: "󰕾", args: ["audio",           "open"] },
        { name: "Displays",         desc: "monitor layouts",     glyph: "󰍹", args: ["monitors",        "open"] },
        { name: "Wallpaper picker", desc: "thumbnail grid",      glyph: "󰋩", args: ["wallpaperpicker", "open"] },
        { name: "Music",            desc: "MPD client",          glyph: "󰝚", args: ["music",           "open"] },
        { name: "Settings",         desc: "feature switches",    glyph: "󰒓", args: ["settings",        "open"] },
        { name: "Screenshot",       desc: "region or output",    glyph: "󰄀", args: ["screenshot",      "open"] },

        { name: "Lock screen",      desc: "and session menu",    glyph: "󰌾", args: ["lock",      "lock"] },
        { name: "Random wallpaper", desc: "from ~/Pictures/bgs", glyph: "󰊠", args: ["wallpaper", "random"] },
        { name: "Flash cursor",     desc: "spotlight",           glyph: "󰍉", args: ["spotlight", "flash"] },
        { name: "Play / pause",     desc: "MPD",                 glyph: "󰐊", args: ["media",     "playpause"] }
    ]

    // ── Keybinds ─────────────────────────────────────────────────────────
    // Read out of reach's config.zon rather than written down here a second
    // time. A palette that advertises the wrong key is worse than one that
    // advertises none, and a label copied into this file is guaranteed to
    // outlive the bind it names — so the binds are MATCHED BY COMMAND: every
    // entry above dispatches `qs ipc call <target> <fn>`, and that exact string
    // is what config.zon spawns, which makes the command the join key and a
    // rebind something this list picks up on its own.
    //
    // Whatever the shake gesture and the media keys are bound to lands here the
    // same way: `.cursor.shake`'s `.command` and an `XF86Audio*` key are both
    // just a spawn of the same string.
    readonly property string configPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/reach/config.zon"

    FileView { id: cfg; path: root.configPath; blockLoading: true; printErrors: false }

    /// { "<target> <fn>": "Super+R  n" }. A flat scan, not a ZON parse: the two
    /// shapes that can carry a command are a bind and a chord entry, and both
    /// put `.key` ahead of the `.spawn`/`.command` on the same line or the one
    /// after. The only state worth tracking is which chord we are inside, which
    /// is the brace depth at the `.chord =` that opened it.
    readonly property var binds: {
        var out = ({});
        var text = cfg.text();
        if (!text) return out;

        var lines = text.split("\n");
        var depth = 0, chordKey = "", chordDepth = -1, pendingKey = "";

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];

            var key = /\.key\s*=\s*"([^"]+)"/.exec(line);
            var cmd = /\.(?:spawn|command)\s*=\s*"qs ipc call ([^"]+)"/.exec(line);

            if (key && /\.chord\s*=/.test(line)) {
                chordKey = key[1];
                chordDepth = depth;
            } else if (key) {
                pendingKey = key[1];
            }

            if (cmd) {
                // `.command` on the shake block has no `.key` of its own; that
                // is the gesture, and it is spelled out rather than left blank.
                var label = pendingKey === "" ? "shake"
                          : (chordDepth >= 0 && chordKey !== "" && pendingKey !== chordKey)
                            ? root.pretty(chordKey) + "  " + pendingKey
                            : root.pretty(pendingKey);
                out[cmd[1].trim()] = label;
                pendingKey = "";
            }

            // Count after the line is read, so a `.chord = .{` opening on this
            // line puts its children one level deeper than the chord itself.
            for (var c = 0; c < line.length; c++) {
                if (line[c] === "{") depth++;
                else if (line[c] === "}") {
                    depth--;
                    if (chordDepth >= 0 && depth <= chordDepth) { chordDepth = -1; chordKey = ""; }
                }
            }
        }
        return out;
    }

    /// config.zon writes keys the way river names them (`Super+Shift+b`,
    /// `XF86AudioPlay`); this is only what a human reads on a menu row.
    function pretty(k) {
        if (k.indexOf("XF86Audio") === 0) return k.slice(9) + " key";
        var parts = k.split("+");
        for (var i = 0; i < parts.length; i++)
            parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        return parts.join("+");
    }

    /// The catalogue with each row's key stamped on, since a row that had to go
    /// looking would need the whole map handed to it to answer.
    readonly property var entries: {
        var out = [];
        for (var i = 0; i < root.catalogue.length; i++) {
            var e = root.catalogue[i];
            // Exact command first, then any bind on the same target — the
            // palette says `<target> open` where a bind says `<target> toggle`
            // and it is the same surface either way. The two passes are not
            // interchangeable: `media` carries three binds, and a loose match
            // taken first would label Play / pause with whichever of prev/next
            // the map happened to yield up.
            var target = e.args[0];
            var want = target + " " + e.args[1];
            var hit = root.binds[want] || "";
            if (hit === "")
                for (var k in root.binds)
                    if (k.indexOf(target + " ") === 0) { hit = root.binds[k]; break; }
            out.push({ name: e.name, desc: e.desc, glyph: e.glyph, args: e.args, key: hit });
        }
        return out;
    }

    /// Case-insensitive substring over the label, then the gloss — the list is
    /// eleven rows, so there is nothing here worth the launcher's file-mode
    /// ranking machinery.
    function search(query) {
        var q = query.toLowerCase().trim();
        if (q === "") return root.entries;
        var out = [];
        var all = root.entries;
        for (var i = 0; i < all.length; i++) {
            var e = all[i];
            if (e.name.toLowerCase().indexOf(q) !== -1 || e.desc.toLowerCase().indexOf(q) !== -1)
                out.push(e);
        }
        return out;
    }

    /// Back in through the front door: the same `qs ipc call` the reach
    /// keybinds use, rather than reaching for the component. Most of these
    /// surfaces are LazyLoader-built components, not singletons, so there is no
    /// name to reach for — and routing every caller through one path means the
    /// palette cannot drift from what the keybind does.
    function run(entry): void {
        Quickshell.execDetached(["qs", "ipc", "call"].concat(entry.args));
    }
}
