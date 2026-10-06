pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

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

    // Volume keys (the `volume` IPC target in shell.qml). Steps go off the last
    // level asked for, not the echoed one: Pipewire reports a write back
    // asynchronously, so a held key stepping off `.volume` would lose presses.
    property real _wantSink: -1
    property real _wantMic: -1
    Timer { id: settle; interval: 300; onTriggered: { root._wantSink = -1; root._wantMic = -1; } }

    function _step(audio, want, d) {
        var v = Math.max(0, Math.min(1, (want >= 0 ? want : audio.volume) + d / 100));
        audio.volume = v;
        settle.restart();
        return v;
    }
    function nudge(d): void    { if (_sinkAudio) _wantSink = _step(_sinkAudio, _wantSink, d); }
    function nudgeMic(d): void { if (_sourceAudio) _wantMic = _step(_sourceAudio, _wantMic, d); }

    // Make the sink named `name` the default (here and from the mixer). The
    // switch itself stays in flip.sh: the optical chain needs a card profile
    // flipped first and playing streams moved, both pactl jobs Quickshell has no
    // API for.
    function useSink(name): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/flip.sh", "set", name]);
    }

    // Cycle the default between the EQ chains (sink-eq.conf).
    function flip(): void {
        var eq = Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.name.startsWith("effect_input.eq_"))
                                      .map(n => n.name).sort();
        if (!eq.length) return;
        root.useSink(eq[(eq.indexOf(sink ? sink.name : "") + 1) % eq.length]);
    }
}
