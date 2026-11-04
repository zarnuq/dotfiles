# GUI test recordings

`wf-recorder` 0.6.0 is installed at `/home/miles/.nix-profile/bin/wf-recorder`.
`grim`, `slurp`, `ffmpeg`, `wl-copy`, and `wl-paste` are also installed.
Recheck availability with the inspector; recording still requires access to
the Wayland session and compositor capture support.

Use `wf-recorder --help` and `--list-output` through the absolute executable
path. Select the connector reported by current output inspection, rather
than assuming the laptop display is the target. For automation, use `-o`
or a known `-g 'x,y WxH'` region instead of interactive `slurp`.

In one persistent shell, start a recording in a fresh artifact directory:

```sh
artifact_dir=$(mktemp -d /tmp/ydotool-test.XXXXXX)
/home/miles/.nix-profile/bin/wf-recorder -o eDP-1 \
  -f "$artifact_dir/test.mp4" >"$artifact_dir/recorder.log" 2>&1 &
recording_pid=$!
trap 'kill -INT "$recording_pid" 2>/dev/null || :; wait "$recording_pid" || :' EXIT
```

Replace `eDP-1` with the verified target. Confirm the recorder stays running
and inspect its log before performing the test. Keep its PID in the same
shell or an orchestration process that owns its lifecycle. When testing ends:

```sh
kill -INT "$recording_pid"
wait "$recording_pid"
trap - EXIT
ffmpeg -i "$artifact_dir/test.mp4" -vf fps=1 -frames:v 10 \
  "$artifact_dir/frame-%03d.png"
```

Stop only this recorder, not all recording processes. SIGINT allows it to
finalize the video. Extract denser frames or specific timestamps for brief
glitches; one frame per second can miss them. Inspect selected PNGs with the
agent's image-viewing tool. Audio is optional and usually unnecessary for
Obsidian tests.

Record the fixture, actions, expected outcome, actual result, and relevant
console errors beside the artifacts. Check saved document contents where
applicable; successful input commands or a video do not establish correctness.

## Example: spreadsheet session (2026-10-10)

What a full real-input pass on an Obsidian plugin looked like, for reuse:

- Opened scratch copies (`xlsx-scratch-*.xlsx`) in new tabs via `obsidian eval` (`app.workspace.getLeaf('tab').openFile(...)`), never the user's originals, and deleted them afterwards.
- Clicked a cell, typed `500` with `type --escape=0`, pressed Enter (`key 28:1 28:0`), then read the recalculated cells back through `obsidian eval`.
- Built a formula by typing `=`, clicking another cell and typing `*2`; Ctrl+Z (`29:1 44:1 44:0 29:0`) and Ctrl+Y (`29:1 21:1 21:0 29:0`) undid and redid it.
- Dragged the fill handle and a column border with the press, two moves, release pattern from SKILL.md.
- Copied with Ctrl+C, pasted with Ctrl+V and checked the system clipboard with `wl-paste -t text/plain`.
- Right-clicked (`click 0xC1`), took a screenshot to find the menu item, clicked it, and pressed Escape (`key 1:1 1:0`) to close a menu that wasn't needed.

Bugs that only real input found: the browser scrolling a container to keep a focused textarea's caret visible, a theme stylesheet overriding a textarea background, and a right-click on a row header acting on the old selection. Synthetic DOM events in unit tests missed all three.
