import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick

// Now-playing + volume widget. Bottom-left, y=450, 420x150.
//
// Native throughout — no subprocess polling:
//   - transport/metadata/art/progress via Quickshell.Services.Mpris (was `mpc`,
//     forked 4×/s). Follows the active MPRIS player, so it also drives Zen etc.,
//     defaulting to MPD. mpd-mpris/mpDris2 is what puts MPD on the MPRIS bus.
//   - volume/mute via Quickshell.Services.Pipewire (was `wpctl`, polled 2×/s).
Widget {
    id: root
    anchors { bottom: true; left: true }
    margins { bottom: s(450) }
    implicitWidth: s(420)
    implicitHeight: s(150)

    // ── Active player: prefer one that's playing, else MPD, else the first. ──
    readonly property var player: {
        var ps = Mpris.players ? Mpris.players.values : [];
        if (ps.length === 0) return null;
        for (var i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i];
        for (var j = 0; j < ps.length; j++)
            if ((ps[j].dbusName || "").toLowerCase().indexOf("mpd") >= 0) return ps[j];
        return ps[0];
    }

    readonly property string title: player ? player.trackTitle : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string art: player ? player.trackArtUrl : ""
    readonly property bool isPlaying: player ? player.isPlaying : false

    // Progress: re-read position on a 1s tick while playing (native, no fork).
    property int _tick: 0
    Timer { interval: 1000; running: root.isPlaying; repeat: true; onTriggered: root._tick++ }
    readonly property real progress: {
        root._tick;   // dependency so the binding re-evaluates each tick
        return (player && player.length > 0)
            ? Math.min(100, Math.max(0, player.position / player.length * 100)) : 0;
    }

    // ── Audio: default sink/source, kept live by the tracker below. ──
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    readonly property int volOut: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    readonly property int volMic: (source && source.audio) ? Math.round(source.audio.volume * 100) : 0
    readonly property bool outMuted: (sink && sink.audio) ? sink.audio.muted : false
    readonly property bool micMuted: (source && source.audio) ? source.audio.muted : false

    Row {
        anchors.fill: parent
        spacing: root.s(10)

        // Album art (hidden when the player exposes none).
        Image {
            visible: root.art !== ""
            width: root.s(120); height: root.s(120)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.art
        }

        Column {
            width: parent.width - (root.art !== "" ? root.s(120) + root.s(10) : 0)
            spacing: root.s(2)

            Txt { text: root.title !== "" ? root.title : "Not playing"; font.bold: true
                  font.pixelSize: root.s(16); width: parent.width; elide: Text.ElideRight }
            Txt { text: root.artist; color: Theme.subtext0; font.pixelSize: root.s(12)
                  width: parent.width; elide: Text.ElideRight; bottomPadding: root.s(6) }

            // Prev / play-pause / next.
            Row {
                width: parent.width
                bottomPadding: root.s(6)
                MpdBtn { width: parent.width / 3; icon: "󰒮"; size: root.s(18); onClicked: if (root.player) root.player.previous() }
                MpdBtn { width: parent.width / 3; icon: root.isPlaying ? "󰏤" : "󰐊"; size: root.s(18); onClicked: if (root.player) root.player.togglePlaying() }
                MpdBtn { width: parent.width / 3; icon: "󰒭"; size: root.s(18); onClicked: if (root.player) root.player.next() }
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
                    onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                }
                VolBtn {
                    width: parent.width / 2
                    icon: root.micMuted ? "󰍭" : "󰍬"; muted: root.micMuted; value: root.volMic
                    onClicked: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
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
