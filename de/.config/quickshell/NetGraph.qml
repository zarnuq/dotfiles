import Quickshell
import Quickshell.Io
import QtQuick

// eww `net-graph` window. Bottom-left, above cpu (y=150).
// Down/up MB/s from /proc/net/dev deltas (native), plus an IP footer.
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(150) }
    implicitWidth: s(420)
    implicitHeight: s(150)

    property real down: 0     // MB/s
    property real up: 0
    property var ips: []      // [{ iface, ip }]

    property real _prevRx: 0
    property real _prevTx: 0

    FileView { id: netDev; path: "/proc/net/dev"; blockLoading: true }

    // Sum rx/tx bytes over real + tunnel interfaces (eth/en/wl), diff over 1s.
    function sample() {
        netDev.reload();
        var lines = netDev.text().split("\n").slice(2);
        var rx = 0, tx = 0;
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].trim().split(/[:\s]+/);
            if (m.length < 10 || !/^(eth|en|wl)/.test(m[0])) continue;
            rx += Number(m[1]);
            tx += Number(m[9]);
        }
        if (root._prevRx > 0) root.down = Math.max(0, (rx - root._prevRx) / 1e6);
        if (root._prevTx > 0) root.up   = Math.max(0, (tx - root._prevTx) / 1e6);
        root._prevRx = rx;
        root._prevTx = tx;
    }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.sample() }

    // IP list: real NICs + tunnels that have a carrier and an address.
    Process {
        id: ipProc
        command: ["sh", "-c",
            "ip -j -4 addr 2>/dev/null | jq -c '[.[] | select(.ifname | test(\"^(eth|en|wl|tun|tap|wg)\")) | select(.flags | index(\"LOWER_UP\")) | select(.addr_info | length > 0) | {iface: .ifname, ip: .addr_info[0].local}]'"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.ips = JSON.parse(text) || []; } catch (e) { root.ips = []; } }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: ipProc.running = true }

    Column {
        anchors.fill: parent
        spacing: root.s(6)

        // Header: down / up values + unit.
        Row {
            id: header
            width: parent.width
            spacing: root.s(12)

            Row {
                spacing: root.s(4)
                Txt { text: "↓"; color: Theme.blue;  font.pixelSize: root.s(18) }
                Txt { text: root.down.toFixed(1); color: Theme.subtext0; font.pixelSize: root.s(11); anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: root.s(4)
                Txt { text: "↑"; color: Theme.green; font.pixelSize: root.s(18) }
                Txt { text: root.up.toFixed(1); color: Theme.subtext0; font.pixelSize: root.s(11); anchors.verticalCenter: parent.verticalCenter }
            }
            Txt {
                text: "MB/s"; color: Theme.subtext0; font.pixelSize: root.s(11)
                width: parent.width - x; horizontalAlignment: Text.AlignRight
            }
        }

        // Overlaid rolling graphs (ceiling NET-MAX = 25 MB/s).
        Item {
            width: parent.width
            height: parent.height - header.height - ipList.height - 2 * parent.spacing

            Graph { anchors.fill: parent; value: root.down; lineColor: Theme.blue;  thickness: root.s(2); maxv: 25 }
            Graph { anchors.fill: parent; value: root.up;   lineColor: Theme.green; thickness: root.s(2); maxv: 25 }
        }

        // IP footer.
        Column {
            id: ipList
            width: parent.width
            Repeater {
                model: root.ips
                Row {
                    width: ipList.width
                    Txt {
                        text: modelData.iface; font.bold: true; font.pixelSize: root.s(11)
                        color: /^(tun|tap|wg)/.test(modelData.iface) ? Theme.mauve : Theme.green
                    }
                    Txt {
                        text: modelData.ip; color: Theme.subtext0; font.pixelSize: root.s(11)
                        width: parent.width - x; horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
