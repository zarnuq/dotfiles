# Agent desktop recipes

Read only the recipe needed for the task. These use the installed `agent-desk`
command. The display is a real headless Wayland desktop; the examples never use
host input injection. Obtain current window IDs with `windows`, rather than
copying an ID from this page.

## How the desktop is set up

**Reach config**, copied from `~/.config/reach/*.zon` at `start` (restart the
desktop for host config edits):

- Default: the user's real binds (the compositor swallows the same chords as
  on the host), but click-to-focus, no window rules, no gaps or borders.
- `agent-desk stop && agent-desk start --real-config`: also the real sloppy
  focus, window rules (Obsidian → desktop 2), gaps and borders. `status --json`
  reports `real_config`. `start` reuses a running desktop, so stop it first.
- Never carried: `.env` (host bus), autostart, gamma, shake-to-find, the
  brightness binds (they drive the real backlight) and the reload bind (a
  reload would read the host's Reach config). Quickshell doesn't run, so
  `qs ipc` binds do nothing.
- Apps get the host `XDG_CONFIG_HOME` / `XDG_CACHE_HOME` (only Reach uses a
  private one), so GTK/dconf dark mode, fonts and app settings match the host.

**Claims.** Commands are serialized, but a sequence isn't atomic. While a claim
is held, input, `clip`, `record`, `run`/`obsidian`, `kill` and window commands
from callers without its token are refused. The user's view, pause, resume and
stop are never refused. `status --json` shows the holder and its idle time left.

**Keys and text.** `key` takes XKB names (`Ctrl`, `Alt`, `Shift`, `Super`,
`Return`, `Escape`, `space`, `plus`, `F1`). For Shift chords it sends the
shifted keysym, because WayVNC otherwise drops every modifier to reach a
lowercase keysym. `key --down Shift` / `key --up Shift` can bracket a short
pointer operation; held input expires after 5 s. `type` uses wtype in the
private desktop, handles leading spaces and Unicode, and refuses while input
is held.

**Clipboard and links.** The clipboard belongs to the private desktop and is
never bridged to the host's (the user's copies may hold secrets). Apps started
by `run`/`obsidian` get an `xdg-open` shim that logs to `opened.log` instead of
opening a browser on the user's real profile; assert on `agent-desk opened`.

**OCR.** `find-text` is for text with no DOM or accessibility tree (canvas
grids, native dialogs). It returns matches in reading order, ignores accents,
and retries across a caret blink. The same text can appear twice (a sheet's
formula bar and its cell): check the target on a screenshot, or use `--all`.

**Closing apps.** `close ID` asks a window to close, and an app can answer with
a dialog (kitty: "Close OS window?"). Windows carry no PID, so `kill PID` ends
an app by the PID `run`/`obsidian` printed; it refuses anything else.

**Accessibility.** `a11y apps` / `a11y tree --depth 4` read the private bus
only. The tested GTK app registers there; Obsidian/Electron does not, so use
the private Obsidian CLI and the DOM for it. Window bounds there are
client-relative; screenshots decide screen coordinates.

**Obsidian config.** Each launch (when the private app isn't running) copies
the real `.obsidian` into `~/notes/.obsidian-agent` without workspace files.
The built plugin goes into `.obsidian-agent/plugins/`, never the user's copy;
hashes are in `~/.local/state/agent-desk/plugin-build.json`. The host app's
`.obsidian` is never written: every launch first checks the config-folder
override from a scratch vault (~4 s) and refuses to open `~/notes` without it.
Copying a bundle into a running app doesn't reload it: close the private
Obsidian or disable/enable the plugin via eval. Use the wrapper's
`obsidian-cli`, which talks only to the private instance; check the vault and
active file in the same eval before any scripted edit.

**doc-works suite** (`scripts/gui-test.py`): claims the desktop and records
the run (the video is kept only on failure). It edits fresh fixture copies in
`~/notes/doc-works-test/gui-<time>/` and checks the saved XML; a test also
fails on uncaught errors or `console.error` lines logged while it ran.
`test_visual_baselines` compares the untouched page / slide / grid with
approved images in `~/.local/state/agent-desk/baselines/doc-works/` (written
on the first run; `UPDATE_BASELINES=1 npm run test:gui -- visual` accepts a
change, and a theme change counts). Python that imports `agent-desk` must run
under `/usr/bin/python3`: Nix's python3 can't load the system libxkbcommon.

**Shells.** Don't launch GUI apps from a shell in a private kitty: the user's
zshrc resets `XDG_RUNTIME_DIR` to the host's, so they would open on the host
desktop. Use `run`, or `kitty --config NONE … zsh -f`. Give other
single-instance apps their own profile.

**User controls.** The Agent desktop app entry (`agent-desk.desktop`, also in
launcher `>` mode) opens the bar panel: Start, View, Take control,
Pause/Resume, Stop. `view` = read-only viewer, `view --control` = pause the
agent and give the user input, `resume` = hand back, `stop` = close this
desktop and its apps. Logs start fresh on each `start`.

## See it and take over

```sh
agent-desk view
```

This opens a live, read-only TigerVNC window on the normal desktop. It attaches
to the existing session and leaves its apps running. To interact instead:

```sh
agent-desk view --control
```

That pauses agent mutations before giving the viewer input. Afterwards:

```sh
agent-desk resume
```

Resume revokes manual input and closes the interactive viewer connection. Open
`view` again to keep watching read-only. Closing the viewer alone leaves the
agent paused. Agents must wait for the user to return ownership before resuming.
There is no TTY to switch to. The bar's AI badge provides these same controls
after the normal Quickshell config has been reloaded.

## Start, inspect and capture

```sh
agent-desk start
agent-desk status --json
agent-desk windows
agent-desk shot /tmp/agent-desktop.png
agent-desk shot --cursor /tmp/agent-desktop-cursor.png
```

`start` reuses a healthy session. Read `running`, `paused` and `manual` before
continuing. View the PNG with the image tool; a successful screenshot command
alone does not establish that the intended UI is present. Screenshot coordinates
are output pixels, with no host 2× pointer correction.

To select a window or bring one back from a hidden desktop, use its current ID:

```sh
agent-desk focus WINDOW_ID
agent-desk geometry WINDOW_ID 100 80 800 600
```

Replace `WINDOW_ID` with the discovered number. Geometry floats that window;
check the reported actual dimensions, because an app can impose minimum sizes.

## Test the current doc-works bundle

Fastest: the repo's suite, which does everything below for docx, xlsx and pptx.

```sh
cd ~/Projects/doc-works && npm run build && npm run test:gui
```

By hand:

```sh
agent-desk obsidian --plugin-dir ~/Projects/doc-works
agent-desk obsidian-cli eval 'code=JSON.stringify({vault:app.vault.adapter.basePath,file:app.workspace.getActiveFile()?.path,view:app.workspace.activeLeaf.view.getViewType(),plugin:app.plugins.plugins["doc-works"]?.manifest.version})'
```

Expect vault `/home/miles/notes` with `configDir` `.obsidian-agent` (add
`cd:app.vault.configDir` to the eval). The launcher copies the built plugin; it
does not run the plugin build. `~/.local/state/agent-desk/plugin-build.json`
records the copied asset hashes.

Copy a fixture into the scratch folder, then open it through the GUI (the
user's quick switcher is disabled):

```sh
mkdir -p ~/notes/doc-works-test/agent && cp ~/Projects/doc-works/tests/fixtures/sample.docx ~/notes/doc-works-test/agent/
agent-desk obsidian-reveal doc-works-test/agent/sample.docx   # prints X Y
agent-desk move X Y && agent-desk click left
agent-desk wait-idle && agent-desk shot /tmp/doc-works-before.png
```

Check the active file is `doc-works-test/agent/sample.docx` with view type
`doc-works-docx-view` before editing.
Then locate the editor on the fresh screenshot, click it with `move` + `click`,
and exercise the requested feature. For a text/save test, after establishing the
caret position:

```sh
agent-desk type -- ' isolated test café λ'
agent-desk key Ctrl+s
agent-desk shot /tmp/doc-works-after.png
```

Verify the saved scratch file or editor state, not only the displayed text. For
Word files, join the `w:t` nodes when checking text: a phrase can span XML runs.
Do not require a literal phrase to be contiguous in raw XML. Use CLI/eval for
setup and assertions; do not replace the GUI interaction being tested with eval.

## Verify a saved .docx

Word splits text into runs, so join the `w:t` of each run and check its
`w:rPr`. Poll: autosave lands a moment after the edit. Example: is "Plain" bold?

```sh
/usr/bin/python3 - ~/notes/doc-works-test/agent/sample.docx Plain <<'PY'
import sys, time, zipfile, xml.etree.ElementTree as ET
W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
path, word = sys.argv[1], sys.argv[2]
for _ in range(40):
    try:
        body = ET.fromstring(zipfile.ZipFile(path).read('word/document.xml'))
    except (zipfile.BadZipFile, KeyError):  # mid-write
        time.sleep(.25); continue
    for r in body.iter(W + 'r'):
        text = ''.join(t.text or '' for t in r.iter(W + 't'))
        b = r.find(f'{W}rPr/{W}b')
        if word in text and b is not None and b.get(W + 'val', 'true') not in ('0', 'false'):
            print('bold:', repr(text)); sys.exit(0)
    time.sleep(.25)
sys.exit(f'{word!r} is not bold in the saved file')
PY
```

The same approach works for slides (`ppt/slides/slideN.xml`, `a:t`) and
sheets (`xl/worksheets/*.xml` via `xl/workbook.xml` + its rels; strings in
`xl/sharedStrings.xml`). `scripts/gui-test.py` has working parsers for all three.

## Refresh a plugin build without touching the host

First obtain agent ownership and finish/save any current scratch work. Discover
and close only the private Obsidian windows, including its Settings window:

```sh
agent-desk windows
agent-desk close PRIVATE_OBSIDIAN_WINDOW_ID
```

Wait until those windows are gone. Build the plugin using that repository's
instructions, then run `obsidian --plugin-dir` again. Recheck the copied hashes,
the loaded plugin version and vault identity. Calling the launcher while the
old app remains open can hand off to that same private app; it does not prove a
changed bundle was reloaded. Avoid stopping the entire desktop if other tests
are using it.

## Keyboard, pointer and accessibility

Examples of literal text and actual input:

```sh
agent-desk type -- 'Text beginning with - stays literal: -example'
agent-desk key Ctrl+Shift+p
agent-desk key Escape
agent-desk move 800 400
agent-desk click right
agent-desk scroll down 3
agent-desk drag 800 400 1000 600
agent-desk key --down Shift
agent-desk move 1000 650
agent-desk click left
agent-desk key --up Shift
agent-desk release
```

Those coordinates are examples: choose real targets from the current screenshot.
Held input expires after five seconds. `type` refuses text while input is held.
Keyboard chords use XKB names; use `plus` for the plus key, for example
`Ctrl+plus`, because `+` separates chord components.

```sh
agent-desk a11y apps
agent-desk a11y tree --depth 4
```

These read only the private accessibility bus. This machine's tested GTK app
registers there; its tested Obsidian/Electron build does not. For Obsidian, use
the checked private CLI and DOM instead. `window_bounds` are client-relative;
`screen_bounds` are included only when the API reports usable values. Confirm
screen coordinates before clicking. The host `ui.py` click commands still use
host ydotool and must not be used here.

## Launch another app

```sh
agent-desk run -- kitty --config NONE --title 'Agent example terminal' /bin/zsh -f
```

This example uses a clean terminal configuration and a shell without user rc
files. Files remain shared. Other singleton apps can still share a profile or
backend service: explicitly give them a separate test profile and verify their
window appears in `agent-desk windows`. The generic launcher cannot infer every
application's profile mechanism.

Only one agent should own a GUI sequence at a time. The supervisor serializes
individual commands, not a multi-command `focus → type → save` transaction.
Concurrent agents can otherwise change each other's focused window inside the
private desktop.

## Check which Reach build is actually running

```sh
agent-desk status --json
sha256sum /usr/bin/reach
```

Compare with the status field `reach_sha256`, captured when that process started.
A compile does not replace an already-running process. After safely finishing
private work and receiving any manual handoff, restart only the agent desktop:

```sh
agent-desk stop
agent-desk start
```

Rediscover window IDs afterwards. Do not restart the normal WM or use process-name
signals to refresh the test desktop.

## Re-run the real-app smoke test

```sh
/usr/bin/python3 ~/dotfiles/tests/agent-desktop/smoke.py
```

It requires an already-running, unpaused desktop. It launches a GTK test app,
checks actual text/pointer/window interactions, private accessibility, screenshots,
manual handoff (including a held modifier) and read-only viewing, then closes
its own window. It does not open a viewer on the host. It prints the directory
containing its PNG and JSON evidence. This is a desktop plumbing test; still
exercise the particular app feature requested by the user.

## Troubleshoot without changing the host

| Symptom | First check |
| --- | --- |
| Agent is paused | User owns control; wait for explicit handoff |
| `focus ID` succeeds but keys go elsewhere | `--real-config` sloppy focus: move the pointer onto the target window |
| A Shift chord types a bare letter | Old `agent-desk`: it must send the shifted keysym (WayVNC level rewrite) |
| App launched but not on screen | `--real-config` window rule sent it to another desktop; `focus ID` |
| Private Obsidian `configDir` is `.obsidian` | Stop the desktop now and report it (the launch check should have refused) |
| `claimed by NAME` | Another agent holds the desktop; wait for it or its idle lapse |
| A link didn't open | Expected: `agent-desk opened` lists it |
| A shortcut does nothing in Obsidian | The user's hotkeys / core plugins apply (quick switcher is off) |
| `libxkbcommon.so.0: cannot open` | Nix python3; use `/usr/bin/python3` |
| App is absent | `status --json` process exit codes, then runtime `app.log`; check profile reuse |
| Wrong private window gets input | Rediscover IDs, focus the target, verify active file/state |
| No Obsidian AT-SPI tree | Use `obsidian-cli`; this is expected for the tested Electron build |
| Reach socket does not appear | Runtime `river.log`; confirm the agent-capable checkout build |
| Private WayVNC helper is missing | Run `python3 ~/.local/share/agent-desk/build-wayvnc.py` |
| Viewer fails to open | Runtime `viewer.log`; verify the host session used to start the supervisor is still valid |
| Shell badge is absent | Check the Agent desktop feature and Quickshell reload; the core works without the widget |

Use the runtime directory reported by `status --json`. Diagnose from the actual
log line before assigning a cause. A read-only screenshot or status query is safe
while paused; app launches, eval and input remain blocked. Never repair a failed
private endpoint by pointing tools at a host socket.

## Example task for a future agent

> Use the agent-desktop skill to test my current doc-works build. Confirm the
> private vault and copied build, open a disposable fixture, exercise the feature
> through actual mouse/keyboard input, verify the saved result, and keep before/
> after screenshots. Leave my host apps alone and stop sending input if I take
> manual control.
