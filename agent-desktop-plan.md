# Isolated agent desktop implementation plan

Status: implemented and exercised locally. Core desktop is running; applying the
normal Quickshell widget is pending a restart choice because hot reload failed.
See `de/.local/share/agent-desk/README.md` for commands, builds and verified limits.

## Goal and chosen design

Run real graphical apps, including Obsidian with doc-works, while Miles works
normally. Agent screenshots, pointer movement, typing, clipboard and window
management must target a separate desktop. Files remain accessible as requested;
this is desktop separation, not a security sandbox.

Use a second **headless river + Reach** with one virtual output, initially
1920×1200 at scale 1. Reuse the actual WM stack, but use a minimal private
configuration. Use Sway only if a logged, reproducible river limitation blocks
the required functions. No additional TTY, VM or container is planned.

Provide one `agent-desk` command, a live viewer for manual access, a small
Quickshell status widget on the normal desktop, and an agent skill. Opening the
viewer attaches to the existing desktop; it must not restart the test apps.

## What was verified locally

- `/usr/bin/river -version`: `0.4.8 +xwayland`.
- `ldd /usr/bin/river`: links `libwlroots-0.20.so`; installed package is
  `gui-libs/wlroots-0.20.2`.
- Installed wlroots headers include headless backend, virtual keyboard,
  virtual pointer and screencopy APIs. Headers alone do not prove river exposes
  these interfaces or that an actual headless launch works.
- river, Reach, grim, dbus-run-session, Obsidian and Quickshell are available.
  wtype, wlrctl, wayvnc and sway were absent from the inspected shell PATH.
- `de/.config/reach/config.zon` hard-codes the host session bus and invokes
  normal autostart. `autostart.sh` starts normal runit user services and resets
  the bus address. Neither is suitable to copy unchanged.
- Reach uses `$XDG_RUNTIME_DIR/reach.sock`. Its source in
  `~/Projects/reach/src/ipc.zig` exposes per-output state and one window title
  per output; it discards client commands and does not expose all windows.
- Normal Quickshell session shutdown uses `pkill -TERM -x river`. With multiple
  river processes this can stop both desktops, so integration must address it.
- Reach source changes in `~/Projects/reach` are authorized. No Git commands,
  privilege elevation, package installation or source modification were run.

## Stage 1 — prove the compositor and input path

1. Inspect river's installed launch options and backend support without touching
   the live compositor. Create a temporary, mode-0700 runtime directory and an
   explicit minimal Reach config. Do not start the regular autostart or shell.
2. Start river using only its headless backend, with a private Wayland socket,
   private D-Bus session, and one virtual output. Never silently fall back to
   DRM, libinput or the parent display. Prefer hardware rendering if it works;
   evaluate software rendering if needed and record the limitation.
3. Query the actual registry for screenshot and virtual input protocols. Start
   a harmless GUI client in that environment and take a real screenshot.
4. Prove keyboard, absolute pointer positioning, buttons, scrolling, drag and
   held modifiers through compositor-scoped input. Prefer maintained packaged
   clients such as wtype/wlrctl when their actual semantics meet these needs.
   Evaluate a persistent helper only if the packaged clients cannot maintain
   state across commands. Never use the host ydotool/uinput path.
5. Verify that host focus, pointer and typing are unaffected. Release held
   input on cancellation. Missing required protocol or failed connection must
   produce an error, never redirect control to the host desktop.

Exit gate: a real client is visible in a captured frame and accepts isolated
input while the host remains usable. Save process logs and exact versions.
If river fails, identify the failing log line before choosing a fallback.

## Stage 2 — wrapper and lifecycle

Implement `de/.local/bin/agent-desk` with these commands:

| Command | Behavior |
| --- | --- |
| `start` / `stop` | Start idempotently; stop only this desktop's processes |
| `status --json` | Health, session identity, output, ownership, viewer state |
| `run -- COMMAND …` | Launch with the desktop's explicit environment |
| `shot PATH` | Capture the virtual output, optionally including the pointer |
| `key` / `type` | Chords, press/release and literal text |
| `move` / `click` / `scroll` / `drag` | Output-local pointer actions |
| `windows --json` / `focus ID` | Enumerate and target real managed windows |
| `pause` / `resume` | Transfer input ownership between agent and human |
| `view` | Attach a viewer to the running desktop |

Keep a private runtime directory under the user's normal runtime directory,
separate config/state paths, instance identity and owned-process records.
All commands load and validate the intended instance before acting. Clear
inherited `DISPLAY`, `WAYLAND_SOCKET`, bus/accessibility addresses and other
host launch endpoints where applicable; supply only agent-session endpoints.
Do not globally update activation environments. Shared files and credentials
remain accessible, but app profiles used by tests must be distinct.

Keep lifecycle operations scoped to recorded processes/process groups with
identity checks; never use broad `pkill river`, `pkill reach`, `killall`, or
unqualified `qs ipc`. Detect dead sessions, stale sockets and partial startup.
Use a per-session input lock; serialize bursts and ensure all keys/buttons are
released when ownership changes. Pause blocks launches and control mutations
from the agent, while allowing status and screenshots.

## Stage 3 — Reach changes where needed

Work in `~/Projects/reach`. Preserve the existing bar's state-socket behavior.
Prefer a separate, opt-in control socket for the agent desktop rather than
turning the current read-only interface into a command channel.

- Publish a complete managed-window inventory with session-scoped stable IDs,
  app ID, title, mapped/focused state, desktop, output and current geometry.
  Publish changes even when the currently selected title stays the same.
- Support only the control operations required by the wrapper: target focus,
  desktop selection, and move/resize where supported. Apply commands in the
  appropriate river manage cycle; return clear errors for stale window IDs.
- Keep shell-specific details out of Reach: no Obsidian profiles, viewer setup,
  test orchestration or widget lifecycle inside the WM.
- Use the private configuration to disable hardware-oriented behavior such as
  gamma changes and raw-device cursor-shake detection in the agent session.

Add focused tests for request parsing, stable IDs, state publication and
invalid-target handling. Build with the project's system Zig toolchain and
run `zig build test`; a successful build alone is not acceptance.

**Recompile checkpoint:** once source changes and relevant checks are ready,
tell Miles explicitly that the changed Reach needs compiling and provide the
exact local build command. First run that build by explicit path in the agent
session and verify its identity. Do not replace or restart the live Reach just
to test the new interface. The inspected Portage ebuild fetches upstream source,
so rebuilding that package alone does not establish that local edits were used.

## Stage 4 — Obsidian and accessibility

Launch Obsidian with a verified separate user-data/profile location and a
dedicated scratch vault. Point test setup at the intended doc-works build and
record the loaded version/build identity. Verify a second real process/window
appears in the agent desktop instead of handing the request to Miles's app.

Keep AT-SPI on a separate accessibility bus as well as a private session bus.
Do not assume dbus-run-session alone proves this: inspect the effective bus
address and enumerate apps from each side. Reuse widget-location logic from
`ui.py` only after replacing its host-input calls with the isolated backend.
Scope any Obsidian CLI/eval connection to the test instance; do not let its
default discovery choose the host app. App APIs may set up and assert tests,
but GUI behavior under test must be exercised through real virtual input.

Exit gate: open a fixture document, edit through the plugin UI, save, verify
the result and capture screenshots, while the normal vault stays usable.

## Stage 5 — manual viewing and status widget

Use WayVNC attached only to the private compositor, with a local-only endpoint
and clipboard bridging disabled. Select the VNC client after checking installed
availability and behavior. `view` defaults to observation; taking control pauses
agent control before enabling viewer input. Agent input resumes only through an
explicit action. If viewer input cannot be gated reliably, use a view-only
connection until a controlled handoff is implemented.

Add a small Quickshell widget to the normal desktop using its existing feature
toggle conventions. It consumes `agent-desk` state and shows:

- Running/stopped/error, agent paused/active, and viewer/manual-control status.
- Complete app/window list with focused app indicated.
- Open viewer, take control/resume, and stop actions.

The widget is a narrow bridge: it does not import the agent's environment into
the host shell. A nested/windowed compositor is an optional diagnostic launch
mode, not the way to view an already-running headless session. Avoid starting a
second full Quickshell until a test specifically requires it. Audit existing
host shutdown/reload actions and change relevant broad signals to target the
host instance, so either session can be managed independently.

## Stage 6 — agent skill and real acceptance

Create an agent-desktop skill with explicit session checks, window discovery,
input ownership, screenshot coordinates and the Obsidian test loop. Leave the
host ydotool skill available for explicit host work; the isolated skill never
falls back to it. Explain the remaining shared-file and shared-resource limits.

Acceptance requires exercising the actual apps, not simulated input logs:

1. Host and agent each receive only their own typing, pointer motion, clicks,
   selection and clipboard operations while Miles actively uses the host.
2. Screenshots contain only the virtual output, with verified coordinates and
   scale, including menus/dialogs and pointer position when requested.
3. Window enumeration covers multiple apps and hidden desktops; focus,
   move/resize and closing dialogs work in the agent session.
4. Obsidian/doc-works tests edit and save fixtures in the new instance; host
   windows are absent from the agent's AT-SPI enumeration and vice versa.
5. Viewer attach/detach preserves apps; take-control pauses agent operations;
   resume releases stale input and returns ownership explicitly.
6. Repeated start/stop, compositor failure and stale runtime state do not stop
   or steal focus from the host. Widget health reflects failures accurately.

Keep logs, screenshots and tested build identities with a short result record.
Report anything that could not be exercised and the exact remaining manual
check. No work is marked complete solely because it compiled.

## Installation and rollout

Implement and validate the compositor proof before committing to package or
WM changes. Resolve actual package names through local Portage metadata first,
then Nix if needed. Kept Portage tools belong in @world via `--noreplace`.
No `doas` command runs without approval for that exact command. Do not run Git
commands without explicit permission. First release is manually started;
autostart and resource-limit services are outside this initial scope.

## Implementation results

- Headless river/Reach runs at 1920×1200 with isolated display, D-Bus and AT-SPI.
- Reach checkout was updated and compiled locally; 24 unit tests passed. The
  normal running Reach remains unchanged; the private session uses the new binary.
- 22 real GUI smoke checks passed, including manual handoff, held-modifier cleanup
  and view-only enforcement.
- Actual TigerVNC rendering was tested in a second disposable desktop.
- doc-works 1.4.2 opened and saved a copied document in a private Obsidian profile;
  literal spaces and Unicode persisted, and the source fixture stayed unchanged.
- 90 QML files passed lint and 33 existing QML tests passed. The panel was rendered
  privately and a fresh full-config load succeeded with unrelated features off.
- Session-specific reload/shutdown, malformed requests and compositor-exit recovery
  were exercised in a disposable desktop without stopping the main agent desktop.
- The host's hot reload reported `Monitors is not a type`, so its old configuration
  remained active. Restarting Quickshell is deferred pending Miles's preference.
- A private WayVNC cursor-capture workaround was necessary for river 0.4.8.
  Installed river/WayVNC were not replaced. Files remain shared as requested.
- Skills for Claude/Codex and session-specific signal routing were installed.
