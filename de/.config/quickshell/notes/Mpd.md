# Mpd

`Mpd.qml` — **fully native, no subprocess polling**: transport/metadata/art/progress via `Quickshell.Services.Mpris` (follows the active MPRIS player, prefers a playing one then MPD — so it also drives Zen etc.; needs the `mpd-mpris` bridge in the `mpd` group service to put MPD on the MPRIS bus), volume/mute via the `Volume` singleton (Pipewire's default sink/source, kept live by its `PwObjectTracker`). Replaced the old `mpc`×4/s + `wpctl`×2/s polling.
