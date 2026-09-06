pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Notification server (replaces mako). Owns org.freedesktop.Notifications,
// keeps a rolling history + a DND flag. Live popups render in
// NotificationPopups; history/DND feed the Notifications widget.
Singleton {
    id: root
    property bool paused: false        // do-not-disturb
    property var history: []           // [{ app, summary, body }], newest first, max 20

    readonly property var live: server.trackedNotifications

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true

        onNotification: (notif) => {
            // History regardless of DND (mako's invisible=1 still logged).
            var h = root.history.slice(0, 19);
            h.unshift({ app: notif.appName || "Unknown",
                        summary: notif.summary || "No summary",
                        body: notif.body || "" });
            root.history = h;

            // DND suppresses the popup; otherwise keep it on-screen.
            if (!root.paused) notif.tracked = true;
        }
    }

    function toggleDnd() { root.paused = !root.paused; }

    // Clear on-screen popups (mako parity: the widget's clear = dismiss -a).
    function clear() {
        var v = server.trackedNotifications.values;
        for (var i = v.length - 1; i >= 0; i--) v[i].dismiss();
    }
}
