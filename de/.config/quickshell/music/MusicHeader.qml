pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Current track, cached MPRIS artwork, playback flags and seek control.
Item {
    id: root
    required property var client
    property string art: ""

    component Flag: Txt {
        property bool on: false
        font.pixelSize: Ui.hfs(13)
        color: on ? Theme.mauve : Theme.surface1
    }
    height: Ui.hs(150)
    Image {
        id: art
        width: Ui.hs(150); height: Ui.hs(150)
        anchors.left: parent.left
        // The MPRIS bridge keeps trackArtUrl after the queue is cleared, so the
        // art alone is not evidence there is anything to show it for. Gate on
        // MPD having a current song, or an emptied queue kept the last cover
        // beside the word "Stopped".
        visible: root.art !== "" && root.client.song.file !== undefined
        source: root.art
        sourceSize.width: Ui.hs(150) * 2
        sourceSize.height: Ui.hs(150) * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Column {
        anchors.left: art.visible ? art.right : parent.left
        anchors.leftMargin: art.visible ? Ui.hs(12) : 0
        anchors.right: flags.left
        anchors.rightMargin: Ui.hs(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.hs(3)

        Txt {
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: Ui.hfs(17)
            font.bold: true
            color: root.client.stopped ? Theme.subtext0 : Theme.text
            text: root.client.stopped ? "Stopped"
                  : root.client.songTitle(root.client.song) || "Nothing playing"
        }
        Txt {
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: Ui.hfs(13)
            color: Theme.subtext0
            text: {
                var a = root.client.song.Artist || "";
                var b = root.client.song.Album || "";
                return a && b ? a + "  ·  " + b : a || b;
            }
        }
        Item {
            width: parent.width
            height: Ui.hs(16)

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - elapsedLabel.width - Ui.hs(10)
                height: Ui.hs(4)
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
                    anchors.topMargin: -Ui.hs(6)
                    anchors.bottomMargin: -Ui.hs(6)
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
                font.pixelSize: Ui.hfs(11)
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
        spacing: Ui.hs(8)

        Flag { text: "󰑖"; on: root.client.repeatOn }
        Flag { text: "󰒝"; on: root.client.randomOn }
        Flag { text: "󰮯"; on: root.client.consumeMode !== "0" }
        Flag { text: "󰎇"; on: root.client.singleMode !== "0" }
        Txt {
            font.pixelSize: Ui.hfs(13)
            color: Theme.subtext0
            text: "󰕾 " + root.client.volume + "%"
        }
    }
}
