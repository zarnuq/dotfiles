import Quickshell
import Quickshell.Io
import QtQuick

// A command re-run on an interval: the Timer + Process + StdioCollector trio
// that every data-providing widget was hand-rolling.
//
// `onData` gets stdout once the command finishes. Re-triggering while the last
// run is still going is a no-op, so a slow command never stacks up copies of
// itself; `refresh()` forces a run between ticks (the calendar's refresh button).
Scope {
    id: root

    property var command: []
    property int interval: 2000
    property bool running: true      // false parks the poll without unloading it

    signal data(string text)

    // Most of these commands print JSON, and every one of their consumers wrote
    // the same try/catch to turn stdout into a list. `jsonData` carries the
    // parsed value, or null when the command failed or printed something that
    // isn't JSON — so a handler is `v => root.items = v || []`.
    signal jsonData(var value)

    function refresh() { proc.running = true; }

    Process {
        id: proc
        command: root.command
        stdout: StdioCollector {
            onStreamFinished: {
                root.data(text);
                var parsed = null;
                try { parsed = JSON.parse(text); } catch (e) { parsed = null; }
                root.jsonData(parsed);
            }
        }
    }

    Timer {
        interval: root.interval
        running: root.running
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
