#!/usr/bin/env python3
"""monitors.py — read and write reach's monitor layouts, in JSON, for the GUI.

reach knows one thing about displays: it opens `monitors.zon` next to config.zon
and applies whatever `.monitors` it finds. Everything else lives here.

    ~/.config/reach/
    ├── config.zon
    ├── monitors.zon -> monitors/laptop.zon     (the choice; gitignored)
    └── monitors/
        ├── laptop.zon                          (the layouts; committed)
        ├── docked.zon
        └── desktop.zon

So a "preset" is a file, and switching is re-pointing a symlink — no selector
field anywhere, and nothing in reach to teach. QML can neither parse nor emit
ZON, and reach cannot write its own config (its state socket is write-only), so
this script is the one place that knows the format.

    state              presets, which is active, and the LIVE outputs
                       (wlr-randr), which is where mode lists come from
    activate <name>    re-point monitors.zon at monitors/<name>.zon, reload reach
    save <name> [json] write monitors/<name>.zon, make it active, reload
    delete <name>      remove a layout file (never the active one)
    apply              reload reach without changing anything

Writes are atomic (temp file + rename), symlink included: a half-written layout
is a file reach refuses wholesale, which means every screen at its default
position.

The ZON subset here is exactly what the schema allows — nested `.{}`, `.field =`
pairs, strings, numbers, enum literals, booleans and `//` comments. That is far
short of real ZON, and deliberately: anything outside it cannot appear in a file
reach will accept for this schema.
"""

import json
import os
import subprocess
import sys
import tempfile
from contextlib import suppress

HEADER_SENTINEL = "\n.{"


# ---------------------------------------------------------------------------
# Paths: the same lookup order reach uses (confparse.zig `locate`), resolved to
# the DIRECTORY, so the GUI edits the files the WM actually reads.
# ---------------------------------------------------------------------------

def reach_dir():
    xdg = os.environ.get("XDG_CONFIG_HOME", "")
    home = os.environ.get("HOME", "")
    candidates = []
    if xdg:
        candidates.append(os.path.join(xdg, "reach"))
    if home:
        candidates.append(os.path.join(home, ".config/reach"))
    candidates.append("/etc/reach")
    for path in candidates:
        if os.path.isdir(path):
            return path
    return candidates[0]


def link_path():
    return os.path.join(reach_dir(), "monitors.zon")


def presets_dir():
    return os.path.join(reach_dir(), "monitors")


def preset_path(name):
    return os.path.join(presets_dir(), name + ".zon")


def active_name():
    """The layout in use, from the link's target. `lexists`, not `exists`: a
    dangling link still records a choice, and reporting it is how the GUI can say
    the file is missing rather than silently showing nothing as active."""
    link = link_path()
    if not os.path.islink(link):
        # A regular file there is legal — reach only cares that it parses — but
        # then no named layout is active, and the GUI says so.
        return None
    name = os.path.basename(os.readlink(link))
    return name[:-4] if name.endswith(".zon") else name


def preset_names():
    try:
        entries = sorted(os.listdir(presets_dir()))
    except OSError:
        return []
    return [e[:-4] for e in entries if e.endswith(".zon")]


# ---------------------------------------------------------------------------
# ZON reading
# ---------------------------------------------------------------------------

class Enum(str):
    """An enum literal (`.rotate_270`). A str subclass so JSON carries it as the
    bare name, with the leading dot restored only when writing back."""


def _tokens(src):
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c in " \t\r\n,":
            i += 1
        elif src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j + 1
        elif src.startswith(".{", i):
            yield ("open", None)
            i += 2
        elif c == "}":
            yield ("close", None)
            i += 1
        elif c == "=":
            yield ("eq", None)
            i += 1
        elif c == '"':
            j = i + 1
            buf = []
            while j < n and src[j] != '"':
                if src[j] == "\\" and j + 1 < n:
                    buf.append(src[j + 1])
                    j += 2
                else:
                    buf.append(src[j])
                    j += 1
            yield ("str", "".join(buf))
            i = j + 1
        elif c == ".":
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            yield ("field", src[i + 1:j])
            i = j
        else:
            j = i
            while j < n and src[j] not in " \t\r\n,}=":
                j += 1
            word = src[i:j]
            if word == "true":
                yield ("val", True)
            elif word == "false":
                yield ("val", False)
            else:
                try:
                    yield ("val", int(word))
                except ValueError:
                    try:
                        yield ("val", float(word))
                    except ValueError:
                        yield ("val", word)
            i = j


def parse_zon(src):
    """`.{}` holding `.field =` entries becomes a dict, otherwise a list.

    Which one it is can only be known from the FIRST token inside the braces, so
    this reads the tokens as a list and looks ahead, rather than guessing and
    promoting later.
    """
    toks = list(_tokens(src))
    pos = 0

    def parse_value():
        nonlocal pos
        kind, value = toks[pos]
        if kind == "open":
            pos += 1
            is_struct = (toks[pos][0] == "field" and pos + 1 < len(toks)
                         and toks[pos + 1][0] == "eq")
            out = {} if is_struct else []
            while pos < len(toks) and toks[pos][0] != "close":
                if is_struct:
                    key = toks[pos][1]
                    pos += 2  # the field name and its `=`
                    out[key] = parse_value()
                else:
                    out.append(parse_value())
            pos += 1
            return out
        # A bare `.name` with no `=` after it is an enum literal, not a key.
        pos += 1
        return Enum(value) if kind == "field" else value

    return parse_value() if toks else {}


def read_layout(path):
    """Returns (header comment, monitor list). Both empty if the file is missing
    or unreadable — a `save` then writes one from scratch."""
    try:
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
    except OSError:
        return "", []
    cut = src.find(HEADER_SENTINEL)
    header = src[:cut + 1] if cut >= 0 else ""
    try:
        doc = parse_zon(src)
    except Exception as exc:  # a file reach would reject too
        print("monitors.py: cannot parse %s: %s" % (path, exc), file=sys.stderr)
        return header, []
    if isinstance(doc, dict):
        return header, doc.get("monitors", []) or []
    return header, []


# ---------------------------------------------------------------------------
# ZON writing
# ---------------------------------------------------------------------------

# Defaults from config.zig's Monitor. A field at its default is left out, so the
# file keeps saying only what it means.
DEFAULTS = {"w": 0, "h": 0, "refresh": 0, "scale": 1.0, "transform": "normal"}
ORDER = ["name", "w", "h", "refresh", "x", "y", "scale", "transform"]

GENERATED_HEADER = """// %s — one reach display layout, written by the display configurator.
//
// Selected by the `monitors.zon` symlink in the parent directory; reach opens
// that path and applies whatever `.monitors` it finds. This header is preserved
// across saves; anything else added by hand below it is not.
"""


def mon_zon(mon):
    parts = []
    for key in ORDER:
        if key not in mon:
            continue
        value = mon[key]
        # x/y are always written: their default (-1) means "don't position me",
        # which is never what a GUI that just placed a rectangle intends.
        if key in DEFAULTS and value == DEFAULTS[key]:
            continue
        if key == "name":
            parts.append('.name = "%s"' % value)
        elif key == "transform":
            parts.append(".transform = .%s" % value)
        elif key == "scale":
            parts.append(".scale = %s" % repr(float(value)))
        else:
            parts.append(".%s = %d" % (key, int(value)))
    return ".{ " + ", ".join(parts) + " }"


def write_layout(path, header, monitors):
    if not header:
        header = GENERATED_HEADER % ("monitors/" + os.path.basename(path))
    lines = [header.rstrip("\n"), ".{", "    .monitors = .{"]
    for mon in monitors:
        lines.append("        %s," % mon_zon(mon))
    lines.append("    },")
    lines.append("}")
    atomic_write(path, "\n".join(lines) + "\n")


def atomic_write(path, body):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".monitors.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(body)
        os.replace(tmp, path)
    except BaseException:
        with suppress(OSError):
            os.unlink(tmp)
        raise


def point_link(name):
    """Re-point monitors.zon at monitors/<name>.zon, atomically.

    os.symlink cannot replace an existing path, and unlink-then-symlink leaves a
    window with no layout at all — which a reload landing in between would read
    as "no monitors.zon". So the new link is made under a temp name and renamed
    over the old one, which is atomic.

    The target is RELATIVE, so the link stays valid through stow: it is resolved
    against the directory it lives in, which is the same directory either way.
    """
    link = link_path()
    tmp = link + ".new"
    with suppress(OSError):
        os.unlink(tmp)
    os.symlink(os.path.join("monitors", name + ".zon"), tmp)
    os.replace(tmp, link)


# ---------------------------------------------------------------------------
# reach
# ---------------------------------------------------------------------------

def reload_reach():
    """SIGHUP. reach re-reads both config files and re-applies the monitor table
    only if it changed by value, so this is cheap and idempotent."""
    try:
        out = subprocess.run(["pidof", "reach"], capture_output=True, text=True)
    except OSError:
        return False
    pids = out.stdout.split()
    if not pids:
        return False
    for pid in pids:
        try:
            os.kill(int(pid), 1)
        except (OSError, ValueError):
            return False
    return True


def live_outputs():
    """wlr-randr's view: what is actually plugged in, and every mode it offers.
    reach publishes neither over its socket, and a GUI cannot offer a mode list
    without it."""
    try:
        out = subprocess.run(["wlr-randr", "--json"], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return []
    if out.returncode != 0:
        return []
    try:
        return json.loads(out.stdout)
    except ValueError:
        return []


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_state():
    presets = []
    for name in preset_names():
        _, monitors = read_layout(preset_path(name))
        presets.append({"name": name, "monitors": monitors})
    active = active_name()
    emit({
        "dir": presets_dir(),
        "link": link_path(),
        "active": active,
        # A link pointing at a file that is gone: the choice is recorded but
        # the layout is not. reach reads that as no file at all.
        "activeMissing": bool(active) and not os.path.isfile(preset_path(active)),
        "presets": presets,
        "outputs": live_outputs(),
    })
    return 0


def cmd_activate(name):
    if not os.path.isfile(preset_path(name)):
        return fail("no layout named '%s'" % name)
    return switch_to(name)


def cmd_save(name, body=None):
    """The layout arrives as JSON: {"monitors": [ ... ]}, argument or stdin.

    The argument form exists for the QML caller: quickshell's Process can write to
    stdin, but that makes the write a second event after the launch, and a layout
    is small enough to hand over in argv in one go."""
    if not name or "/" in name or name.startswith("."):
        return fail("bad layout name '%s'" % name)
    try:
        incoming = json.loads(body) if body is not None else json.load(sys.stdin)
    except ValueError as exc:
        return fail("bad JSON: %s" % exc)
    monitors = incoming.get("monitors", [])
    if not monitors:
        return fail("layout '%s' has no outputs" % name)

    path = preset_path(name)
    header, _ = read_layout(path)
    write_layout(path, header, monitors)
    return switch_to(name)


def cmd_delete(name):
    if active_name() == name:
        # Deleting the live layout would leave monitors.zon dangling, which
        # reach reads as no file — a layout nobody chose and nothing shows.
        return fail("'%s' is active; switch to another layout first" % name)
    try:
        os.unlink(preset_path(name))
    except OSError as exc:
        return fail("cannot delete '%s': %s" % (name, exc))
    return ok(reloaded=False)


def switch_to(name):
    """Make monitors/<name>.zon the live layout and tell reach."""
    point_link(name)
    return ok(reloaded=reload_reach(), active=name)


# Every command answers with one JSON line on stdout — the QML side reads that,
# not the exit status.
def emit(payload):
    json.dump(payload, sys.stdout)
    print()


def ok(**extra):
    emit(dict({"ok": True}, **extra))
    return 0


def fail(message):
    emit({"ok": False, "error": message})
    return 1


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "state":
        return cmd_state()
    if cmd == "apply":
        return ok(reloaded=reload_reach())
    if cmd in ("activate", "save", "delete"):
        if len(argv) < 3:
            return fail("%s needs a layout name" % cmd)
        if cmd == "save":
            return cmd_save(argv[2], argv[3] if len(argv) > 3 else None)
        return {"activate": cmd_activate, "delete": cmd_delete}[cmd](argv[2])
    return fail("unknown command '%s'" % cmd)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
