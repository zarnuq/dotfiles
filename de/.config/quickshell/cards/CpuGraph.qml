pragma ComponentBehavior: Bound
import Quickshell.Io
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Usage and network in one card, bottom of the left stack. Two plot bands
// because the scales don't mix: cpu/gpu/ram/disk in percent on top, down/up
// MB/s (/proc/net/dev deltas, ceiling 25) below. IPs on one footer line.
Widget {
    id: root
    anchors { bottom: true; left: true }
    implicitWidth: s(420)
    implicitHeight: s(180)

    property real down: 0     // MB/s
    property real up: 0
    property var ips: []      // [{ iface, ip }]

    property real _prevRx: 0
    property real _prevTx: 0

    FileView { id: netDev; path: "/proc/net/dev"; blockLoading: true }

    // Sum rx/tx bytes over real interfaces (eth/en/wl), diff over 1s.
    function sample(): void {
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

    // Real NICs + tunnels with a carrier and an address; `ip -j` is filtered here, no jq.
    Poll {
        command: ["ip", "-j", "-4", "addr"]
        interval: 10000
        onJsonData: v => root.ips = (v || [])
            .filter(l => /^(eth|en|wl|tun|tap|wg)/.test(l.ifname)
                         && (l.flags || []).indexOf("LOWER_UP") !== -1
                         && (l.addr_info || []).length > 0)
            .map(l => ({ iface: l.ifname, ip: l.addr_info[0].local }))
    }

    Column {
        anchors.fill: parent
        spacing: root.s(6)

        // Header: usage labels left (cpu/gpu over their temps), net rates right.
        Item {
            id: header
            width: parent.width
            height: usage.height

            Row {
                id: usage
                spacing: root.s(12)

                Column {
                    Txt { text: "cpu"; font.pixelSize: root.s(18) }
                    Txt { text: Sys.cpuTemp + "°"; color: Theme.subtext0; font.pixelSize: root.s(11) }
                }
                Column {
                    Txt { text: "gpu"; color: Theme.blue; font.pixelSize: root.s(18) }
                    Txt { text: Sys.gpuTemp + "°"; color: Theme.subtext0; font.pixelSize: root.s(11) }
                }
                Txt { text: "ram";  color: Theme.green; font.pixelSize: root.s(18) }
                Txt { text: "disk"; color: Theme.peach; font.pixelSize: root.s(18) }
            }

            Column {
                anchors.right: parent.right
                Row {
                    anchors.right: parent.right
                    spacing: root.s(4)
                    Txt { text: "↓"; color: Theme.teal; font.pixelSize: root.s(18) }
                    Txt { text: root.down.toFixed(1); color: Theme.subtext0; font.pixelSize: root.s(11); anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: "↑"; color: Theme.mauve; font.pixelSize: root.s(18) }
                    Txt { text: root.up.toFixed(1); color: Theme.subtext0; font.pixelSize: root.s(11); anchors.verticalCenter: parent.verticalCenter }
                }
                Txt { anchors.right: parent.right; text: "MB/s"; color: Theme.subtext0; font.pixelSize: root.s(11) }
            }
        }

        Item {
            id: plots
            width: parent.width
            height: parent.height - header.height - ipLine.height - 2 * parent.spacing

            Item {
                width: parent.width
                height: Math.round(parent.height * 0.6)
                Graph { value: Sys.cpu;  lineColor: Theme.text }
                Graph { value: Sys.gpu;  lineColor: Theme.blue;  thickness: root.s(3) }
                Graph { value: Sys.ram;  lineColor: Theme.green }
                Graph { value: Sys.disk; lineColor: Theme.peach }
            }

            Rectangle { y: Math.round(plots.height * 0.6); width: parent.width; height: 1; color: Theme.surface0 }

            Item {
                y: Math.round(parent.height * 0.6) + 1
                width: parent.width
                height: parent.height - y
                Graph { value: root.down; lineColor: Theme.teal;  maxv: 25 }
                Graph { value: root.up;   lineColor: Theme.mauve; maxv: 25 }
            }
        }

        // iface ip · iface ip — tunnels in mauve.
        Row {
            id: ipLine
            width: parent.width
            spacing: root.s(10)
            clip: true
            Repeater {
                model: root.ips
                Row {
                    id: ipItem
                    required property var modelData
                    spacing: root.s(4)
                    Txt {
                        text: ipItem.modelData.iface; font.bold: true; font.pixelSize: root.s(11)
                        color: /^(tun|tap|wg)/.test(ipItem.modelData.iface) ? Theme.mauve : Theme.green
                    }
                    Txt { text: ipItem.modelData.ip; color: Theme.subtext0; font.pixelSize: root.s(11) }
                }
            }
        }
    }
}
