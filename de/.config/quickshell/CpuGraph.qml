import QtQuick

// eww `cpu` window + `cpu-gpu-graph` widget. Bottom-left, 420x150.
// Four overlaid rolling graphs: cpu / gpu / ram / disk.
Widget {
    id: root
    anchors { bottom: true; left: true }
    implicitWidth: s(420)
    implicitHeight: s(150)

    Column {
        anchors.fill: parent
        spacing: root.s(6)

        // Header: cpu/gpu stacked over their temps, then ram / disk labels.
        Row {
            id: header
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

        Item {
            width: parent.width
            height: parent.height - header.height - parent.spacing

            Graph { anchors.fill: parent; value: Sys.cpu;  lineColor: Theme.text;  thickness: root.s(2) }
            Graph { anchors.fill: parent; value: Sys.gpu;  lineColor: Theme.blue;  thickness: root.s(3) }
            Graph { anchors.fill: parent; value: Sys.ram;  lineColor: Theme.green; thickness: root.s(2) }
            Graph { anchors.fill: parent; value: Sys.disk; lineColor: Theme.peach; thickness: root.s(2) }
        }
    }
}
