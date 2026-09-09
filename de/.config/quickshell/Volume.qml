pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire

// The default sink and source, and the handful of numbers everything wants off
// them. Three surfaces — the bar's status blocks, the now-playing card and the
// OSD — each held their own copy of this: the same two Pipewire properties, the
// same PwObjectTracker keeping them bound, and the same volume/muted arithmetic
// spelled out again.
//
// A node only publishes `.audio` while something holds a binding on it, which is
// what the tracker is for; one tracker here serves every reader.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property int volume: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    readonly property int micVolume: (source && source.audio) ? Math.round(source.audio.volume * 100) : 0
    // Muted is the safe default: an unmuted mic is what the bar flags in red, so
    // a source we can't read yet must not spend a frame claiming the room is live.
    readonly property bool micMuted: (source && source.audio) ? source.audio.muted : true

    // The device's own name, unformatted — the bar trims ALSA's boilerplate out
    // of it for its status block, the OSD shows it as-is.
    readonly property string sinkName:
        sink ? (sink.description || sink.nickname || sink.name || "") : ""

    function toggleMute()    { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; }
    function toggleMicMute() { if (source && source.audio) source.audio.muted = !source.audio.muted; }
}
