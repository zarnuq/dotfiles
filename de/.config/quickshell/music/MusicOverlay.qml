pragma ComponentBehavior: Bound
import QtQuick
// Parent import: `Txt` (and the root singletons) live one level up. A QML
// file does NOT see its parent directory implicitly — only its own.
import ".."

// Dismissible song metadata and keyboard help.
Rectangle {
    id: root
    property string mode: ""
    property var song: null
    signal dismissed()
    property real fontScale: 1.2
    function s(n) { return Config.s(n); }
    function fs(n) { return Math.round(root.s(n) * root.fontScale); }

    component HelpRow: Row {
        id: hr
        required property var modelData
        readonly property bool heading: hr.modelData.k === ""
        spacing: root.s(12)
        topPadding: hr.heading ? root.s(10) : 0
        Txt {
            width: root.s(140)
            horizontalAlignment: Text.AlignRight
            text: hr.modelData.k
            color: Theme.mauve
            font.pixelSize: root.fs(12)
        }
        Txt {
            text: hr.modelData.v
            color: hr.heading ? Theme.subtext0 : Theme.text
            font.bold: hr.heading
            font.pixelSize: root.fs(12)
        }
    }

    visible: root.mode !== ""
    color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.96)

    MouseArea { anchors.fill: parent; onClicked: root.dismissed() }
    Flickable {
        anchors.fill: parent
        anchors.margins: root.s(24)
        visible: root.mode === "info"
        contentHeight: infoCol.height
        clip: true

        Column {
            id: infoCol
            width: parent.width
            spacing: root.s(4)

            Txt {
                text: "song info"
                color: Theme.mauve
                font.pixelSize: root.fs(15)
                font.bold: true
                bottomPadding: root.s(8)
            }

            Repeater {
                model: {
                    var s = root.song;
                    if (!s) return [];
                    var out = [];
                    for (var k in s) if (k !== "_type") out.push({ k: k, v: s[k] });
                    return out;
                }
                delegate: Row {
                    id: infoRow
                    required property var modelData
                    spacing: root.s(12)
                    Txt {
                        width: root.s(120)
                        text: infoRow.modelData.k
                        color: Theme.subtext0
                        font.pixelSize: root.fs(12)
                    }
                    Txt {
                        width: infoCol.width - root.s(132)
                        text: infoRow.modelData.v
                        wrapMode: Text.Wrap
                        font.pixelSize: root.fs(12)
                    }
                }
            }
        }
    }
    Flickable {
        anchors.fill: parent
        anchors.margins: root.s(24)
        visible: root.mode === "help"
        contentHeight: helpCol.height
        clip: true

        Column {
            id: helpCol
            width: parent.width
            spacing: root.s(3)

            Txt {
                text: "keybinds"
                color: Theme.mauve
                font.pixelSize: root.fs(15)
                font.bold: true
                bottomPadding: root.s(8)
            }

            Repeater {
                model: [
                    { k: "", v: "playback" },
                    { k: "p / s", v: "play-pause / stop" },
                    { k: "H / L", v: "previous / next track" },
                    { k: "← / →", v: "seek ∓5s" },
                    { k: "↑ / ↓", v: "volume ±5" },
                    { k: "Z X C V", v: "repeat · random · consume · single" },
                    { k: "", v: "tabs" },
                    { k: "1 – 5", v: "queue · directories · playlists · lyrics · search" },
                    { k: "Tab / S-Tab", v: "next / previous tab" },
                    { k: "", v: "navigation" },
                    { k: "j / k", v: "down / up" },
                    { k: "g / G", v: "top / bottom" },
                    { k: "C-d / C-u", v: "half page down / up" },
                    { k: "/ then n / N", v: "search · next / previous match" },
                    { k: "c", v: "jump to playing song" },
                    { k: "", v: "queue" },
                    { k: "Enter", v: "play the selected song" },
                    { k: "Space / C-Space", v: "select · invert selection" },
                    { k: "d / D", v: "delete selected · clear the queue" },
                    { k: "J / K", v: "move the song down / up" },
                    { k: "", v: "directories · playlists" },
                    { k: "h / l", v: "up a level · open" },
                    { k: "Enter", v: "play it now" },
                    { k: "a", v: "add to the queue (a folder adds all of it)" },
                    { k: "A", v: "add this whole folder" },
                    { k: "D", v: "delete the playlist" },
                    { k: "C-a", v: "save the queue as a playlist" },
                    { k: "", v: "library search" },
                    { k: "type", v: "search as you type" },
                    { k: "Esc / ↓", v: "leave the field for the results" },
                    { k: "T", v: "cycle the tag (any · artist · album · title · …)" },
                    { k: "a / A", v: "add the row · add every match" },
                    { k: "", v: "other" },
                    { k: "i / ~", v: "song info · this help" },
                    { k: "q / Esc", v: "close" }
                ]
                delegate: HelpRow {}
            }
        }
    }
}
