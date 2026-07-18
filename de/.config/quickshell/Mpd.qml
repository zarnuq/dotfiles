import Quickshell
import Quickshell.Io
import QtQuick

// eww `mpd` window (mpd + volume, combined). Bottom-left, y=450, 420x150.
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(450) }
    implicitWidth: s(420)
    implicitHeight: s(150)

    property string title: ""
    property string artist: ""
    property string status: "paused"   // playing / paused
    property int progress: 0            // 0..100
    property string cover: ""           // file path, or ""
    property int coverNonce: 0          // cache-buster for Image

    property int volOut: 0
    property int volMic: 0
    property bool outMuted: false
    property bool micMuted: false

    // Track metadata in one poll (\x1f-separated to survive spaces).
    Process {
        id: meta
        command: ["sh", "-c",
            "printf '%s\\x1f%s\\x1f%s\\x1f%s' " +
            "\"$(mpc current -f '%title%' 2>/dev/null)\" " +
            "\"$(mpc current -f '%artist%' 2>/dev/null)\" " +
            "\"$(mpc status 2>/dev/null | grep -q playing && echo playing || echo paused)\" " +
            "\"$(mpc 2>/dev/null | sed -n 's/.*( *\\([0-9]*\\)%).*/\\1/p')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.split("\x1f");
                root.title = p[0] || ""; root.artist = p[1] || "";
                root.status = p[2] || "paused"; root.progress = Number(p[3]) || 0;
            }
        }
    }
    // Album art: extract embedded picture to a temp file (path or "").
    Process {
        id: art
        command: ["sh", "-c",
            "f=$(mpc current -f '%file%' 2>/dev/null); [ -z \"$f\" ] && { echo; exit 0; }; " +
            "mpc readpicture \"$f\" > /tmp/qs-mpd-cover.jpg 2>/dev/null; " +
            "case \"$(file -b --mime-type /tmp/qs-mpd-cover.jpg)\" in image/*) echo /tmp/qs-mpd-cover.jpg;; *) echo;; esac"]
        stdout: StdioCollector {
            onStreamFinished: { root.cover = text.trim(); root.coverNonce++; }
        }
    }
    // Output/mic volume + mute (0.5s).
    Process {
        id: vol
        command: ["sh", "-c",
            "o=$(wpctl get-volume @DEFAULT_AUDIO_SINK@); i=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@); " +
            "printf '%s %s %s %s' " +
            "\"$(echo \"$o\" | awk '{printf \"%.0f\", $2*100}')\" \"$(echo \"$o\" | grep -q MUTED && echo 1 || echo 0)\" " +
            "\"$(echo \"$i\" | awk '{printf \"%.0f\", $2*100}')\" \"$(echo \"$i\" | grep -q MUTED && echo 1 || echo 0)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(" ");
                root.volOut = Number(p[0]) || 0; root.outMuted = p[1] === "1";
                root.volMic = Number(p[2]) || 0; root.micMuted = p[3] === "1";
            }
        }
    }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: { meta.running = true; art.running = true; } }
    Timer { interval: 500; running: true; repeat: true; triggeredOnStart: true
            onTriggered: vol.running = true }

    Row {
        anchors.fill: parent
        spacing: root.s(10)

        // Album art (hidden when absent).
        Image {
            visible: root.cover !== ""
            width: root.s(120); height: root.s(120)
            fillMode: Image.PreserveAspectCrop
            cache: false
            source: root.cover === "" ? "" : "file://" + root.cover + "?" + root.coverNonce
        }

        Column {
            width: parent.width - (root.cover !== "" ? root.s(120) + root.s(10) : 0)
            spacing: root.s(2)

            Txt { text: root.title !== "" ? root.title : "Not playing"; font.bold: true
                  font.pixelSize: root.s(16); width: parent.width; elide: Text.ElideRight }
            Txt { text: root.artist; color: Theme.subtext0; font.pixelSize: root.s(12)
                  width: parent.width; elide: Text.ElideRight; bottomPadding: root.s(6) }

            // Prev / play-pause / next.
            Row {
                width: parent.width
                bottomPadding: root.s(6)
                MpdBtn { width: parent.width / 3; icon: "󰒮"; size: root.s(18); onClicked: Quickshell.execDetached(["mpc", "prev"]) }
                MpdBtn { width: parent.width / 3; icon: root.status === "playing" ? "󰏤" : "󰐊"; size: root.s(18); onClicked: Quickshell.execDetached(["mpc", "toggle"]) }
                MpdBtn { width: parent.width / 3; icon: "󰒭"; size: root.s(18); onClicked: Quickshell.execDetached(["mpc", "next"]) }
            }

            // Progress.
            Rectangle {
                width: parent.width; height: root.s(4); radius: root.s(3); color: Theme.surface0
                Rectangle { width: parent.width * root.progress / 100; height: parent.height; radius: root.s(3); color: Theme.mauve }
            }

            // Volume: output + mic, click to mute-toggle.
            Row {
                width: parent.width
                topPadding: root.s(8)
                VolBtn {
                    width: parent.width / 2
                    icon: root.outMuted ? "󰖁" : "󰕾"; muted: root.outMuted; value: root.volOut
                    onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                }
                VolBtn {
                    width: parent.width / 2
                    icon: root.micMuted ? "󰍭" : "󰍬"; muted: root.micMuted; value: root.volMic
                    onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
                }
            }
        }
    }

    // --- local button flavours (kept inline: used only by this widget) ---
    component MpdBtn: MouseArea {
        property string icon: ""
        property real size: 18
        implicitHeight: size * 1.3
        hoverEnabled: true
        Txt { anchors.centerIn: parent; text: parent.icon
              color: parent.containsMouse ? Theme.text : Theme.subtext0; font.pixelSize: parent.size }
    }
    component VolBtn: MouseArea {
        id: vbtn
        property string icon: ""
        property int value: 0
        property bool muted: false
        implicitHeight: root.s(26)
        Row {
            anchors.centerIn: parent
            spacing: root.s(8)
            Txt { text: vbtn.icon; color: vbtn.muted ? Theme.red : Theme.text; font.pixelSize: root.s(20) }
            Txt { text: vbtn.value + "%"; font.pixelSize: root.s(14); anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
