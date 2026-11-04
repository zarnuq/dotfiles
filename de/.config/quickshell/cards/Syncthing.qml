pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Syncthing status, bottom-right (above the battery card when that one exists).
//
// Talks to syncthing's REST API with QML's own XMLHttpRequest — no curl fork
// per tick. The API key is read out of syncthing's config.xml, so it never
// lands in a process argv. Header: overall completion; rows: each folder's
// state, then each remote device's connection.
Widget {
    id: root
    anchors { bottom: true; right: true }
    margins { bottom: Config.batteryPresent && Config.on("battery") ? s(75) : 0 }
    implicitWidth: s(300)
    implicitHeight: body.height + s(root.pad * 2)

    readonly property string api: "http://127.0.0.1:8384/rest/"
    property string apiKey: ""
    property bool up: false          // last request got an answer
    property real completion: 100
    property real needBytes: 0
    property var folders: []         // [{ label, state, need }]
    property var devices: []         // [{ name, connected }]

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/syncthing/config.xml"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var m = /<apikey>([^<]+)<\/apikey>/.exec(text());
            root.apiKey = m ? m[1] : "";
        }
    }

    function get(path, cb): void {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var v = null;
            if (x.status === 200) try { v = JSON.parse(x.responseText); } catch (e) {}
            cb(v);
        };
        x.open("GET", root.api + path);
        x.setRequestHeader("X-API-Key", root.apiKey);
        x.send();
    }

    function refresh(): void {
        get("db/completion", function(v) {
            root.up = v !== null;
            if (!v) return;
            root.completion = v.completion;
            root.needBytes = v.needBytes;
        });
        get("config/folders", function(fs) {
            if (!fs) return;
            var out = [];
            fs.forEach(function(f, i) {
                out.push({ label: f.label || f.id, state: f.paused ? "paused" : "…", need: 0 });
                if (f.paused) return;
                root.get("db/status?folder=" + encodeURIComponent(f.id), function(s) {
                    if (!s) return;
                    var copy = root.folders.slice();
                    if (!copy[i]) return;
                    copy[i] = { label: copy[i].label, state: s.state, need: s.needBytes };
                    root.folders = copy;
                });
            });
            root.folders = out;
        });
        get("config/devices", function(ds) {
            if (!ds) return;
            root.get("system/connections", function(c) {
                if (!c) return;
                var conns = c.connections || {};
                // Our own device has no entry in connections — that's how it's skipped.
                root.devices = ds.filter(function(d) { return conns[d.deviceID] !== undefined; })
                    .map(function(d) {
                        return { name: d.name || d.deviceID.slice(0, 7), connected: conns[d.deviceID].connected };
                    });
            });
        });
    }

    Timer {
        interval: 10000
        running: root.apiKey !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function bytes(n) {
        var u = ["B", "KB", "MB", "GB", "TB"], i = 0;
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
        return n.toFixed(i ? 1 : 0) + " " + u[i];
    }

    function stateColor(s) {
        return s === "idle" ? Theme.green
             : s === "paused" ? Theme.overlay0
             : s.indexOf("error") >= 0 ? Theme.red
             : Theme.peach;   // syncing, scanning, waiting…
    }

    Column {
        id: body
        width: parent.width
        spacing: root.s(6)

        CardHeader {
            icon: "󰓦"
            iconColor: !root.up ? Theme.red : root.completion < 100 ? Theme.peach : Theme.green
            label: "Syncthing"
            Txt {
                font.pixelSize: root.s(14)
                text: root.apiKey === "" ? "no config"
                    : !root.up ? "offline"
                    : root.completion < 100 ? Math.floor(root.completion) + "% · " + root.bytes(root.needBytes)
                    : "up to date"
            }
        }

        Repeater {
            model: root.up ? root.folders : []
            delegate: Row {
                id: folder
                required property var modelData
                width: body.width
                Txt { text: "󰉋  " + folder.modelData.label; font.pixelSize: root.s(13)
                      width: parent.width - st.width; elide: Text.ElideRight }
                Txt {
                    id: st
                    font.pixelSize: root.s(13)
                    color: root.stateColor(folder.modelData.state)
                    text: folder.modelData.state + (folder.modelData.need > 0 ? " · " + root.bytes(folder.modelData.need) : "")
                }
            }
        }

        Repeater {
            model: root.up ? root.devices : []
            delegate: Row {
                id: device
                required property var modelData
                width: body.width
                Txt { text: "󰍹  " + device.modelData.name; font.pixelSize: root.s(13)
                      width: parent.width - conn.width; elide: Text.ElideRight }
                Txt {
                    id: conn
                    font.pixelSize: root.s(13)
                    color: device.modelData.connected ? Theme.green : Theme.overlay0
                    text: device.modelData.connected ? "connected" : "offline"
                }
            }
        }
    }
}
