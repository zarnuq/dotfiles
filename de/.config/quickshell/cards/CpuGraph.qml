pragma ComponentBehavior: Bound
import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Sys, Volume,
// Reach, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

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

            Graph { value: Sys.cpu;  lineColor: Theme.text }
            Graph { value: Sys.gpu;  lineColor: Theme.blue;  thickness: root.s(3) }
            Graph { value: Sys.ram;  lineColor: Theme.green }
            Graph { value: Sys.disk; lineColor: Theme.peach }
        }
    }
}
