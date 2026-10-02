pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Pipewire

// The default sink and source, and the numbers the bar, the now-playing card
// and the OSD want off them. A node only publishes `.audio` while something
// holds a binding on it; the one tracker here serves every reader.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker { objects: [root.sink, root.source] }

    // null until the node is bound, which is every reader's "not yet" case.
    readonly property var _sinkAudio: sink ? sink.audio : null
    readonly property var _sourceAudio: source ? source.audio : null

    readonly property int volume: _sinkAudio ? Math.round(_sinkAudio.volume * 100) : 0
    readonly property bool muted: _sinkAudio ? _sinkAudio.muted : false

    readonly property int micVolume: _sourceAudio ? Math.round(_sourceAudio.volume * 100) : 0
    // Muted is the safe default: an unmuted mic is what the bar flags in red, so
    // a source we can't read yet must not spend a frame claiming the room is live.
    readonly property bool micMuted: _sourceAudio ? _sourceAudio.muted : true

    // A device's own name, unformatted — the bar trims ALSA's boilerplate out
    // of it for its status block, the OSD and the mixer show it as-is.
    function nameOf(n) { return n ? (n.description || n.nickname || n.name || "") : ""; }
    readonly property string sinkName: nameOf(sink)

    function toggleMute(): void    { if (_sinkAudio) _sinkAudio.muted = !_sinkAudio.muted; }
    function toggleMicMute(): void { if (_sourceAudio) _sourceAudio.muted = !_sourceAudio.muted; }
}
