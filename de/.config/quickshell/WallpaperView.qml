import Quickshell
import Quickshell.Wayland
import QtQuick

// One background-layer surface per output, all showing Wallpaper.current.
// Switching crossfades between two layers so it never flashes black: the new
// image loads into the hidden layer and only fades in once fully decoded.
//
// Memory: the two layers exist ONLY for the ~0.7s crossfade. cache:true +
// a single shared sourceSize (Wallpaper.decodeSize) make every output's
// visible layer reference the SAME decoded pixmap in QQuickPixmapCache -- so
// N identical monitors cost one buffer, not N. Once a fade finishes the
// hidden layer drops its source, so at steady state only ONE buffer is
// referenced for the whole desktop (swww-style), the other layer holds none.
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
                sourceSize: Wallpaper.decodeSize   // one shared size -> one shared decode
                cache: true                        // dedupe identical decodes across outputs
                asynchronous: true
                opacity: bg.aFront ? 1 : 0
                // Once faded out, drop the buffer so only the visible layer holds pixels.
                Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad
                    onRunningChanged: if (!running && a.opacity === 0) a.source = "" } }
            }
            Image {
                id: b
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Wallpaper.decodeSize
                cache: true
                asynchronous: true
                opacity: bg.aFront ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad
                    onRunningChanged: if (!running && b.opacity === 0) b.source = "" } }
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
