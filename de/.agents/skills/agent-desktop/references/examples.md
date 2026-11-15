# Agent desktop recipes

Read only the recipe needed for the task. These use the installed `agent-desk`
command. The display is a real headless Wayland desktop; the examples never use
host input injection. Obtain current window IDs with `windows`, rather than
copying an ID from this page.

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

Copy a fixture into the scratch folder, then open it through the GUI. The user's
quick switcher is disabled, so reveal it in the file explorer and click it:

```sh
mkdir -p ~/notes/doc-works-test/agent && cp ~/Projects/doc-works/tests/fixtures/sample.docx ~/notes/doc-works-test/agent/
agent-desk obsidian-cli eval 'code=(()=>{const l=app.workspace.getLeavesOfType("file-explorer")[0];app.workspace.revealLeaf(l);l.view.revealInFolder(app.vault.getAbstractFileByPath("doc-works-test/agent/sample.docx"));const r=document.querySelector(".nav-file-title[data-path=\"doc-works-test/agent/sample.docx\"]").getBoundingClientRect();return JSON.stringify([r.x+r.width/2,r.y+r.height/2])})()'
agent-desk move X Y && agent-desk click left
agent-desk shot /tmp/doc-works-before.png
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
