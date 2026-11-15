---
name: agent-desktop
description: Test graphical apps and Obsidian plugins on Miles's isolated headless river/Reach desktop while he uses his normal desktop. Use for GUI testing, screenshots and automated mouse/keyboard interactions; use the host ydotool skill only when the task explicitly needs his existing desktop.
---

# Isolated graphical testing

`~/.local/bin/agent-desk` drives a private second river/Reach desktop (one
1920×1200 screen, scale 1) with its own display, clipboard, D-Bus and
accessibility bus. **Files are the real ones** (same home, same `~/notes`):
edit only scratch copies. Details and recipes: [references/examples.md](references/examples.md).

## Rules

- Never send input to the host: no ydotool, no host `ui.py`, no host Obsidian
  CLI, no broad `pkill`, no unqualified `qs ipc`. If the desktop is unhealthy,
  read the logs in the runtime dir from `status --json`.
- A paused or manual session is the user's. Never `resume` it yourself; wait.
- Claim the desktop for any multi-step sequence, and release it afterwards. A
  refusal names the holder: wait, don't steal it.
- If a sandbox blocks `agent-desk` (`Operation not permitted` on its socket),
  ask for permission to run it. Don't work around the sandbox.
- Don't open a viewer (`view`) during unattended work; it opens a window on the
  user's desktop.
- Exercise the feature under test with real input. Use eval only for setup and
  assertions, then verify saved files or app state, not just pixels.

## Workflow

```sh
agent-desk start                              # idempotent
eval "$(agent-desk claim my-task 120)"        # exports AGENT_DESK_CLAIM; lapses after 120 s idle
agent-desk run -- APP …                       # prints the PID (kill PID ends it)
agent-desk wait-window APP                    # prints the window id
agent-desk wait-idle                          # instead of sleeps
agent-desk shot /tmp/s.png                    # read it before choosing coordinates
agent-desk move X Y; agent-desk click left
agent-desk type -- 'literal text, café λ'
agent-desk key Ctrl+Shift+z                   # XKB names; write Shift chords naturally
agent-desk unclaim
```

If each command runs in a fresh shell (Codex and similar), the exported token
is lost between calls. Keep it in the private runtime dir and source it in
every call:

```sh
agent-desk claim my-task 120 > "$XDG_RUNTIME_DIR/agent-desk/my-task.claim"
. "$XDG_RUNTIME_DIR/agent-desk/my-task.claim" && agent-desk key Ctrl+b
. "$XDG_RUNTIME_DIR/agent-desk/my-task.claim" && agent-desk unclaim && rm "$XDG_RUNTIME_DIR/agent-desk/my-task.claim"
```

Also: `focus ID`, `close ID`, `geometry ID X Y W H`, `scroll down 3`,
`drag X1 Y1 X2 Y2`, `key --down/--up`, `release`, `shot --window ID`,
`clip set -- TEXT` / `clip get` (private clipboard, `--type text/html`),
`record start PATH` / `record stop`, `opened` (links apps tried to open; never
opened), `find-text TEXT` (OCR → `X Y`), `compare A B --diff D` (pixel diff),
`a11y tree`. Coordinates are screen pixels; the window fills the screen at 0,0.
No 2× correction.

## Obsidian / doc-works

```sh
cd ~/Projects/doc-works && npm run build && npm run test:gui   # the suite (npm/node: ~/.nix-profile/bin)
agent-desk obsidian --plugin-dir ~/Projects/doc-works          # manual use
agent-desk obsidian-cli eval 'code=JSON.stringify([app.vault.adapter.basePath, app.vault.configDir, app.workspace.getActiveFile()?.path])'
cp ~/Projects/doc-works/tests/fixtures/sample.docx ~/notes/doc-works-test/my-test.docx
agent-desk obsidian-reveal doc-works-test/my-test.docx         # prints X Y of its explorer row
agent-desk move X Y && agent-desk click left                   # opens it
```

The private Obsidian opens the real `~/notes` with its own config folder
`.obsidian-agent`: a copy of the user's `.obsidian` (theme, plugins, hotkeys),
plus the test build of the plugin. Expect `configDir` `.obsidian-agent`. If it
is `.obsidian`, run `agent-desk stop` at once and report it. Put test files
only in `~/notes/doc-works-test/` and delete them afterwards. The user's quick
switcher is **off**: open files with `obsidian-reveal` + a click. To verify a
saved Office file, read its XML (recipe in examples.md: "Verify a saved
.docx"). Extend `scripts/gui-test.py` with `test_*` functions for new features.
