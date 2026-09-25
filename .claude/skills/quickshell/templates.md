# Templates

Skeletons lifted from files that work — start from the named file when you need
more than the skeleton shows. Every one already follows the conventions in
SKILL.md (Bound, `id: root`, qualified delegate access, `: void`).

## Ambient card — `cards/Foo.qml`

Model: `cards/Clock.qml` (simplest), `cards/Weather.qml` (Poll + CardHeader).
`Widget` pins to the main screen, draws the flat card and pads its children;
`s()` is callable unqualified inside it.

```qml
pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Where it sits in the stack, and what it reads.
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(600) }            // a slot in the card chain — see CLAUDE.md
    implicitWidth: s(420)
    implicitHeight: s(150)

    property var items: []

    Poll {
        command: ["some-cmd", "--json"]
        interval: 10000
        onJsonData: v => root.items = (v || []).filter(x => x.ok)
    }

    Column {
        anchors.fill: parent
        spacing: root.s(6)

        CardHeader { icon: "󰖐"; label: "Foo" }

        Repeater {
            model: root.items
            Txt {
                id: line
                required property var modelData
                text: line.modelData.name
                color: Theme.subtext0
                font.pixelSize: root.s(12)
            }
        }
    }
}
```

## List menu — `Foo.qml` at the root

Model: `Settings.qml` (smallest), `Audio.qml` (a slot control), `Network.qml`.
`Picker` owns the overlay on every output, IPC (`toggle`/`hide`/`open`), sizing
from `rows`, j/k/arrows/Escape/Return. You supply `rows`, `activate(i)` and the
row look.

```qml
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

Picker {
    id: root
    ipcTarget: "foomenu"                  // qs ipc call foomenu toggle

    // Flat list; { kind: "header" } rows are skipped by navigation.
    rows: [
        { kind: "header", label: "Things" },
        { kind: "thing", label: "One", value: 1 },
        { kind: "thing", label: "Two", value: 2 }
    ]

    boxWidth: s(420)
    barHeight: s(30)                      // only if the bar below draws something

    function activate(i): void {
        if (!selectable(i)) return;
        Quickshell.execDetached(["notify-send", root.rows[i].label]);
        root.hide();
    }

    box: Component {
        PickerList {
            picker: root

            // Keys navKey didn't take. Accept to claim one.
            onExtraKey: function (e) {
                if (e.key !== Qt.Key_D) return;
                // …
                e.accepted = true;
            }

            rowDelegate: PickerRow {
                id: rowItem
                picker: root
                width: parent.width
                onActivated: root.activate(rowItem.index)
                icon: "󰄬"
                label: rowItem.isHeader ? "" : rowItem.modelData.label
                trailing: rowItem.isHeader ? "" : String(rowItem.modelData.value)
            }

            // Children are the bottom bar.
            Txt {
                anchors.centerIn: parent
                text: "enter picks · d does the other thing"
                color: Theme.surface1
                font.pixelSize: root.s(11)
            }
        }
    }
}
```

Polls inside a menu run only while it is up: `running: root.open`.

## Type-to-filter picker

Model: `launcher/Launcher.qml`, `ClipboardPicker.qml`. Leave `rows` empty, point
`count` at your results so `move()` walks them, and compose
`PickerSearch` (the field: Esc/arrows/Ctrl+J/K, `submitted`, `extraKey`) over
`PickerResults` (`model`, `delegate`, `emptyText`, required `emptySize`). Each
delegate row wraps a `PickerHover { picker: root; row: entry.index; onActivated: … }`
so hover selects only on real pointer movement.

## A window you sit in — `foo/Foo.qml`

Model: `monitors/Monitors.qml`, `music/Music.qml`.

```qml
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Scope {
    id: root
    property bool open: false

    IpcHandler {
        target: "foo"
        function toggle(): void { root.open = !root.open; }
        function hide(): void   { root.open = false; }
        function open(): void   { root.open = true; }
    }

    FloatingWindow {
        visible: root.open
        title: "Foo"                      // reach rules must match this, not just app_id
        color: Theme.base
        implicitWidth: Config.s(900)
        implicitHeight: Config.s(600)
        onClosed: root.open = false       // the WM closed it

        // Built on open, destroyed on close: no state or focus survives hidden.
        Loader {
            anchors.fill: parent
            active: root.open
            sourceComponent: FooView {}
        }
    }
}
```

## Shared state — `Foo.qml` at the root

Model: `Volume.qml`, `Sys.qml`. Root-level singletons are registered
automatically; one in a subfolder needs a `qmldir` listing the whole folder.

```qml
pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real level: 0

    // /proc and /sys: read natively, never fork for them.
    FileView { id: src; path: "/sys/class/foo/level"; blockLoading: true }

    function sample(): void {
        src.reload();
        root.level = Number(src.text().trim()) || 0;
    }

    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.sample() }
}
```

If nothing is always on screen to read it, gate the Timer on a consumer (a
`running: someone.open` binding) rather than polling for nobody.
