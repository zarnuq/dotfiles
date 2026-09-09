pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Window-manager state, read from reach's socket (src/ipc.zig).
//
// reach is river's window manager, not a compositor plugin, so nothing about
// desktops, focus or window titles is exposed through any Wayland protocol —
// river is non-monolithic and has no workspace concept of its own to publish.
// reach sends it to us instead: one JSON line per state change on
// $XDG_RUNTIME_DIR/reach.sock, each line a COMPLETE snapshot of every output.
//
// Whole snapshots rather than deltas is what makes reconnection free: there is
// no resync step and no way to end up applying changes out of order. The line
// that arrives on connect is the current state, so a bar started at any moment
// (or restarted after a reach restart) is correct on its first frame.
//
// The socket is read-only by design — see the header of reach's ipc.zig for why
// clicking a desktop cell isn't wired through it.
Singleton {
    id: root

    // Output name ("DP-2") -> { desktop, focused, fullscreen, occupied[], title, appId }.
    property var outputs: ({})
    property int desktops: 9

    readonly property bool connected: sock.connected

    /// State for one output, or null if reach hasn't mentioned it (or isn't up).
    function forScreen(name) {
        return root.outputs[name] || null;
    }

    Socket {
        id: sock
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/reach.sock"
        connected: true

        parser: SplitParser {
            splitMarker: "\n"
            onRead: line => root.ingest(line)
        }
    }

    // reach restarting (or not having started yet) is the normal case at login,
    // since runsv brings quickshell up independently of the session.
    //
    // Driven by `running` rather than by the socket's own state-changed signal:
    // a connection that FAILS never entered the connected state, so there is no
    // state change to hear, and the first attempt would be the only one — the bar
    // would stay blank for the rest of the session. Re-arming off the property
    // instead retries until it takes, and stops itself the moment it does.
    // 5s rather than 1s only to keep the log quiet: every failed attempt logs a
    // socket error, and the normal case never retries at all (reach's autostart
    // starts runsvdir, so reach is listening before quickshell exists).
    Timer {
        interval: 5000
        repeat: true
        running: !sock.connected
        onTriggered: sock.connected = true
    }

    function ingest(line) {
        if (!line || line.length === 0)
            return;

        var data;
        try {
            data = JSON.parse(line);
        } catch (e) {
            console.warn("Reach: unparseable state line:", e);
            return;
        }

        var byName = {};
        for (var i = 0; i < data.outputs.length; i++)
            byName[data.outputs[i].name] = data.outputs[i];

        root.desktops = data.desktops;
        // Assigned, never mutated: QML only notifies on assignment, and every
        // bar's cells are bound to this.
        root.outputs = byName;
    }
}
