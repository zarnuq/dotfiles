# Clipboard

`Clipboard.qml` — `Scope` with a `Variants` over `["text", "image"]` instantiating two self-restarting `Process` watchers (`wl-paste --type text/image --watch cliphist store`); inherits qs's `WAYLAND_DISPLAY` (no socket-wait needed). Replaced the runit `cliphist` group service. The picker half is `ClipboardPicker.qml` now, not `clipfzf`.
