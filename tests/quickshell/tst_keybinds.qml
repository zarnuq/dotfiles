import QtQuick
import QtTest
import "../../de/.config/quickshell/Keybinds.js" as Keybinds

TestCase {
    name: "Keybinds"

    readonly property string zon: [
        ".{",
        "    .border_thickness = 2,",
        "    .binds = .{",
        "        // launchers",
        "        .{ .key = \"Super+space\", .action = .{ .spawn = \"qs ipc call launcher toggle\" } },",
        "        .{ .key = \"Super+z\", .action = .{ .spawn = \"kitty --class float -e $HOME/.local/bin/svfzf\" } },",
        "        .{ .key = \"Super+r\", .chord = .{",
        "            // not a header: inside the chord",
        "            .{ .key = \"s\", .action = .{ .spawn = \"exec steam </dev/null >/dev/null 2>&1\" } },",
        "        } },",
        "        // focus /",
        "        // layout",
        "        .{ .key = \"Super+h\", .action = .{ .setmfact = -0.05 } },",
        "        .{ .key = \"Super+Left\", .action = .{ .move = .{ .x = -40 } } },",
        "        .{ .key = \"Super+Shift+r\", .action = .reload },",
        "    },",
        "    .rules = .{ .{ .key = \"not a bind\" } },",
        "}"
    ].join("\n")

    function binds(rows) { return rows.filter(r => r.kind === "bind"); }

    function test_parse() {
        var rows = Keybinds.parse(zon);
        var mine = rows.slice(0, rows.length - Keybinds.DESKTOP_ROWS.length);
        compare(mine.map(r => r.kind === "header" ? "# " + r.label : r.key + " = " + r.action), [
            "# launchers",
            "Super+Space = launcher toggle",
            "Super+Z = kitty --class float -e svfzf",
            "# Super+R, then",
            "Super+R  s = steam",
            "# focus / layout",
            "Super+H = setmfact -0.05",
            "Super+Left = move x -40",
            "Super+Shift+R = reload"
        ]);
        compare(rows.slice(mine.length), Keybinds.DESKTOP_ROWS);
    }

    function test_noBinds() {
        compare(Keybinds.parse(".{ .border_thickness = 2 }"), []);
        compare(Keybinds.parse(""), []);
    }

    function test_filter() {
        var rows = Keybinds.parse(zon);
        // A bind match keeps its header; non-matching sections vanish.
        compare(Keybinds.filter(rows, "steam").map(r => r.label || r.key), ["Super+R, then", "Super+R  s"]);
        // A header match keeps the whole section.
        compare(binds(Keybinds.filter(rows, "LAYOUT")).length, 3);
        compare(Keybinds.filter(rows, "").length, rows.length);
        compare(Keybinds.filter(rows, "zzzz"), []);
    }
}
