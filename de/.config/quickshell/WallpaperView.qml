import Quickshell
import Quickshell.Wayland
import QtQuick

// One background-layer surface per output, all showing Wallpaper.current.
// Switching crossfades between two layers so it never flashes black: the new
// image loads into the hidden layer and only fades in once fully decoded.
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

        Item {
            id: bg
            anchors.fill: parent
            readonly property string cur: Wallpaper.current
            property bool aFront: true   // which layer is currently shown

            // Two stacked layers; the visible one stays fully opaque until the
            // other has finished loading, then they crossfade (~0.7s).
            Image {
                id: a
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width, height)   // decode at output res, not native
                cache: false
                asynchronous: true
                opacity: bg.aFront ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
            }
            Image {
                id: b
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width, height)
                cache: false
                asynchronous: true
                opacity: bg.aFront ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
            }

            // New wallpaper -> load into the hidden layer.
            onCurChanged: {
                if (cur === "") return;
                var back = aFront ? b : a;
                back.source = "file://" + cur;
            }
            // ...and flip only once that layer is decoded, so no black gap.
            Connections {
                target: a
                function onStatusChanged() { if (!bg.aFront && a.status === Image.Ready) bg.aFront = true; }
            }
            Connections {
                target: b
                function onStatusChanged() { if (bg.aFront && b.status === Image.Ready) bg.aFront = false; }
            }

            Component.onCompleted: if (cur !== "") a.source = "file://" + cur;
        }
    }
}
