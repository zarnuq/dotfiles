pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import "../Keybinds.js" as Keybinds
import ".."

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
// and what the query matches, `desc` is the dimmed right-hand label — the slot
// file mode fills with `dir`, the parent directory.
Singleton {
    id: root

    // `open`, never `toggle`: picking "Music" out of a list must put the music
    // window up, and toggle would take it down whenever it was already there.
    // Picker and Music both expose `open` for this (`show` is unusable — the
    // CLI eats `qs ipc call <target> show` as its own `qs ipc show`).
    readonly property var catalogue: [
        { name: "Agent desktop",    desc: "isolated app testing", glyph: "󰚩", args: ["agentdesk", "open"] },
        { name: "Network",          desc: "Wi-Fi + VPN",         glyph: "󰤨", args: ["network",         "open"] },
        { name: "Bluetooth",        desc: "devices + pairing",   glyph: "󰂯", args: ["bluetooth",       "open"] },
        { name: "Drives",           desc: "mount + eject USB",   glyph: "󰋊", args: ["drives",          "open"] },
        { name: "Processes",        desc: "kill by name",        glyph: "󰆴", args: ["processes",       "open"] },
        { name: "tmux",             desc: "sessions tree",       glyph: "󰆍", args: ["tmux",            "open"] },
        { name: "Notifications",    desc: "history + DND",       glyph: "󰂚", args: ["notifications",   "open"] },
        { name: "Clipboard",        desc: "history picker",      glyph: "󰅍", args: ["clipboard",       "open"] },
        { name: "Audio",            desc: "sinks + mixer",       glyph: "󰕾", args: ["audio",           "open"] },
        { name: "Displays",         desc: "monitor layouts",     glyph: "󰍹", args: ["monitors",        "open"] },
        { name: "Power modes",      desc: "perf / balanced / saver", glyph: "󰓅", args: ["powermode",   "open"] },
        { name: "Wallpaper picker", desc: "thumbnail grid",      glyph: "󰋩", args: ["wallpaperpicker", "open"] },
        { name: "Palette",          desc: "Mocha / wallpaper",   glyph: "󰏘", args: ["theme",           "open"] },
        { name: "Music",            desc: "MPD client",          glyph: "󰝚", args: ["music",           "open"] },
        { name: "Settings",         desc: "feature switches",    glyph: "󰒓", args: ["settings",        "open"] },
        { name: "Keybinds",         desc: "cheatsheet",          glyph: "󰌌", args: ["keybinds",        "open"] },

        { name: "Lock screen",      desc: "and session menu",    glyph: "󰌾", args: ["lock",      "lock"] },
        { name: "Random wallpaper", desc: "from ~/Pictures/bgs", glyph: "󰊠", args: ["wallpaper", "random"] },
        { name: "Screenshot / record", desc: "capture menu",  glyph: "󰄀", args: ["screenshots",     "open"] },
        { name: "Annotate clipboard", desc: "image → annotator", glyph: "󰏬", args: ["capture",   "annotate"] },
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
    readonly property string configPath:
        Config.configHome + "/reach/config.zon"

    FileView { id: cfg; path: root.configPath; blockLoading: true; printErrors: false }

    /// { "<target> <fn>": "Super+R  n" }, from Keybinds.js's rows of the `.binds` block.
    readonly property var binds: {
        // `.cursor.shake`'s `.command` sits outside `.binds` and has no `.key`: the gesture.
        var shake = cfg.text().match(/\.shake\s*=\s*\.\{[^}]*\.command\s*=\s*"qs ipc call ([^"]+)"/);
        var out = shake ? { [shake[1]]: "shake" } : {};
        Keybinds.parse(cfg.text()).forEach(r => { if (r.kind === "bind") out[r.action] = r.key; });
        return out;
    }

    /// The catalogue with each row's key stamped on, since a row that had to go
    /// looking would need the whole map handed to it to answer.
    readonly property var entries: root.catalogue.map(e => {
        // Exact command first, then any bind on the same target — the
        // palette says `<target> open` where a bind says `<target> toggle`
        // and it is the same surface either way. The two passes are not
        // interchangeable: `media` carries three binds, and a loose match
        // taken first would label Play / pause with whichever of prev/next
        // the map happened to yield up.
        var key = root.binds[e.args.join(" ")]
                  || root.binds[Object.keys(root.binds).find(k => k.startsWith(e.args[0] + " "))] || "";
        return Object.assign({ key: key }, e);
    })

    /// Case-insensitive substring over the label, then the gloss — the list is
    /// a dozen rows, so there is nothing here worth the launcher's file-mode
    /// ranking machinery.
    function search(query) {
        var q = query.toLowerCase().trim();
        return root.entries.filter(e => e.name.toLowerCase().includes(q) || e.desc.toLowerCase().includes(q));
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
