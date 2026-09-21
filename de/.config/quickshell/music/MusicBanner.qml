pragma ComponentBehavior: Bound
import QtQuick
// Parent import: `Txt` (and the root singletons) live one level up. A QML
// file does NOT see its parent directory implicitly — only its own.
import ".."

// Transient confirmation that something reached the queue. Driven by the
// controller noticing the queue GREW, so it covers every route in — a/A, Enter,
// loading a playlist, even an add made from rmpc or mpc while this is open.
//
// Opacity only: under QT_QUICK_BACKEND=software there are no shaders, and a
// fade on a flat rectangle is the one cheap transition available.
Rectangle {
    id: root

    required property MusicController controller
    property real fontScale: 1.2
    function s(n) { return Config.s(n); }
    function fs(n) { return Math.round(root.s(n) * root.fontScale); }

    readonly property bool shown: root.controller.notice !== ""

    implicitWidth: label.implicitWidth + accent.width + root.s(28)
    implicitHeight: root.s(34)
    color: Theme.surface0
    border.color: Theme.mauve
    border.width: 1
    radius: Theme.borderRadius

    visible: root.opacity > 0
    opacity: root.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    // Slides up a few pixels as it appears rather than only fading, so it
    // registers as arriving from the status bar.
    transform: Translate { y: root.shown ? 0 : root.s(6)
                           Behavior on y { NumberAnimation { duration: 140 } } }

    Rectangle {
        id: accent
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        anchors.margins: 1
        width: root.s(3)
        color: Theme.mauve
    }

    Txt {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: accent.right
        anchors.leftMargin: root.s(12)
        font.pixelSize: root.fs(12)
        color: Theme.text
        // Held while fading out so the text does not vanish before the box.
        text: root.controller.notice !== "" ? root.controller.notice : label.text
    }
}
