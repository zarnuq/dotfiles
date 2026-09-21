pragma ComponentBehavior: Bound
import QtQuick
// Parent import: `Txt` (and the root singletons) live one level up. A QML
// file does NOT see its parent directory implicitly — only its own.
import ".."

// Current track, cached MPRIS artwork, playback flags and seek control.
Item {
    id: root
    required property var client
    property string art: ""
    property real fontScale: 1.2
    function s(n) { return Config.s(n); }
    function fs(n) { return Math.round(root.s(n) * root.fontScale); }

    component Flag: Txt {
        property bool on: false
        font.pixelSize: root.fs(13)
        color: on ? Theme.mauve : Theme.surface1
    }
    height: root.s(96)
    Image {
        id: art
        width: root.s(96); height: root.s(96)
        anchors.left: parent.left
        visible: root.art !== ""
        source: root.art
        sourceSize.width: root.s(96) * 2
        sourceSize.height: root.s(96) * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Column {
        anchors.left: art.visible ? art.right : parent.left
        anchors.leftMargin: art.visible ? root.s(12) : 0
        anchors.right: flags.left
        anchors.rightMargin: root.s(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.s(3)

        Txt {
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: root.fs(17)
            font.bold: true
            color: root.client.stopped ? Theme.subtext0 : Theme.text
            text: root.client.stopped ? "Stopped"
                  : root.client.songTitle(root.client.song) || "Nothing playing"
        }
        Txt {
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: root.fs(13)
            color: Theme.subtext0
            text: {
                var a = root.client.song.Artist || "";
                var b = root.client.song.Album || "";
                return a && b ? a + "  ·  " + b : a || b;
            }
        }
        Item {
            width: parent.width
            height: root.s(16)

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - elapsedLabel.width - root.s(10)
                height: root.s(4)
                color: Theme.surface0

                Rectangle {
                    height: parent.height
                    color: Theme.mauve
                    width: root.client.duration > 0
                           ? parent.width * Math.min(1, root.client.elapsed / root.client.duration)
                           : 0
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -root.s(6)
                    anchors.bottomMargin: -root.s(6)
                    onClicked: function (e) {
                        if (root.client.duration > 0)
                            root.client.seekTo(root.client.duration * e.x / width);
                    }
                }
            }

            Txt {
                id: elapsedLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: root.fs(11)
                color: Theme.subtext0
                text: root.client.fmtTime(root.client.elapsed) + " / "
                      + root.client.fmtTime(root.client.duration)
            }
        }
    }
    Row {
        id: flags
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.s(8)

        Flag { text: "󰑖"; on: root.client.repeatOn }
        Flag { text: "󰒝"; on: root.client.randomOn }
        Flag { text: "󰮯"; on: root.client.consumeMode !== "0" }
        Flag { text: "󰎇"; on: root.client.singleMode !== "0" }
        Txt {
            font.pixelSize: root.fs(13)
            color: Theme.subtext0
            text: "󰕾 " + root.client.volume + "%"
        }
    }
}
