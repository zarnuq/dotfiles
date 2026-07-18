import Quickshell
import Quickshell.Wayland
import QtQuick

// One background-layer surface per output, all showing Wallpaper.current.
// (awww put the same image on every monitor; this mirrors that.)
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-wallpaper"
        exclusiveZone: 0
        color: "black"
        anchors { top: true; bottom: true; left: true; right: true }

        Image {
            anchors.fill: parent
            source: Wallpaper.current === "" ? "" : "file://" + Wallpaper.current
            fillMode: Image.PreserveAspectCrop
            // Decode at output resolution, not the image's native size. Without this a
            // 6016x6016 wallpaper decodes to ~138MB per surface; capped it's ~20MB.
            sourceSize: Qt.size(width, height)
            cache: false
            asynchronous: true
        }
    }
}
