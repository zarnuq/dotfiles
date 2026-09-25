pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
// Parent import: the Reach singleton, which this tells where the pointer is.
import ".."

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
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-wallpaper"
        exclusiveZone: 0
        color: "black"
        anchors { top: true; bottom: true; left: true; right: true }

        // The wallpaper is the only surface covering a WHOLE output, which makes
        // it the only place hover can answer "which screen is the mouse on" for
        // the bar's highlight (see Reach.hoveredOutput). Hover only — it takes no
        // clicks and changes no focus; reach ignores shell-surface interaction
        // anyway, so a click on the desktop still does nothing.
        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    Reach.hoveredOutput = win.modelData.name;
                else if (Reach.hoveredOutput === win.modelData.name)
                    Reach.hoveredOutput = "";
            }
        }

        Item {
            id: bg
            anchors.fill: parent
            readonly property string cur: Wallpaper.current
            property bool aFront: true   // which layer is currently shown

            // Two stacked layers; the visible one stays fully opaque until the
            // other has finished loading, then they crossfade (~0.7s). One
            // declaration for both, so the shared-buffer settings can't drift
            // between them.
            component Layer: Image {
                id: layer
                property bool shown
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Wallpaper.decodeSize   // one shared size -> one shared decode
                cache: true                        // dedupe identical decodes across outputs
                asynchronous: true
                opacity: layer.shown ? 1 : 0
                // Once faded out, drop the buffer so only the visible layer holds pixels.
                Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad
                    onRunningChanged: if (!running && layer.opacity === 0) layer.source = "" } }
            }

            // New wallpaper -> load into the hidden layer...
            onCurChanged: {
                if (cur === "") return;
                var back = aFront ? b : a;
                back.source = "file://" + cur;
            }
            // ...and flip only once that layer is decoded, so no black gap.
            Layer { id: a; shown: bg.aFront;  onStatusChanged: if (!bg.aFront && status === Image.Ready) bg.aFront = true }
            Layer { id: b; shown: !bg.aFront; onStatusChanged: if (bg.aFront && status === Image.Ready) bg.aFront = false }

            Component.onCompleted: if (cur !== "") a.source = "file://" + cur;
        }
    }
}
