#!/usr/bin/env python3
"""Run agy, codex and vibe headless as subagents and report each subscription's headroom.

  delegate.py status [--json]
  delegate.py run {codex,agy,vibe,auto} [--edit] [--cd DIR] [--model M] [--prefer a,b,c] PROMPT
  delegate.py selftest

`run` prints only the subagent's final answer plus one footer line; the full transcript
goes to a log file named in the footer. Exit codes: 0 ok, 1 failure, 2 quota hit, 124 timeout.
"""
import argparse
import fnmatch
import glob
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "ai-cli-subagents"
LEDGER = STATE / "ledger.jsonl"
CLIS = ("codex", "agy", "vibe")
# Checked only when a run fails, so an answer that merely discusses rate limits never trips it.
QUOTA_RE = re.compile(r"quota|rate.?limit|usage limit|RESOURCE_EXHAUSTED|\b429\b|too many requests", re.I)
# Fallback cooldowns when the CLI gives no reset time. agy on Google AI Pro refills every 5h.
COOLDOWN = {"codex": 3600, "agy": 5 * 3600, "vibe": 3600}
# Below this much headroom in either codex window, auto mode skips codex.
CODEX_MIN_HEADROOM = 10
AGY_READ_ONLY = "\n\nThis is a read-only task: do not create, modify or delete any files."


def now():
    return time.time()


def fmt_time(ts):
    return datetime.fromtimestamp(ts).strftime("%a %d %b %H:%M")


def find_key(obj, key):
    """Depth-first search for the first value stored under `key`."""
    if isinstance(obj, dict):
        if key in obj:
            return obj[key]
        obj = list(obj.values())
    if isinstance(obj, list):
        for v in obj:
            found = find_key(v, key)
            if found is not None:
                return found
    return None


def read_ledger():
    try:
        lines = LEDGER.read_text().splitlines()
    except FileNotFoundError:
        return []
    out = []
    for line in lines:
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return out


def append_ledger(entry):
    STATE.mkdir(parents=True, exist_ok=True)
    with LEDGER.open("a") as f:
        f.write(json.dumps(entry) + "\n")


def cooldown_until(cli, ledger):
    hits = [e["until"] for e in ledger if e["cli"] == cli and e.get("until")]
    until = max(hits, default=0)
    return until if until > now() else None


# ---- usage readers: each CLI's own logs first, our ledger where the CLI keeps none ----

def codex_limits():
    """Latest rate-limit snapshot codex wrote into its session rollouts."""
    files = sorted(glob.glob(str(HOME / ".codex/sessions/*/*/*/rollout-*.jsonl")), key=os.path.getmtime)
    for f in reversed(files[-10:]):
        for line in reversed(Path(f).read_text(errors="replace").splitlines()):
            if '"rate_limits"' not in line:
                continue
            try:
                rl = find_key(json.loads(line), "rate_limits")
            except json.JSONDecodeError:
                continue
            if rl:
                return rl, os.path.getmtime(f)
    return None, None


def codex_status(ledger):
    rl, seen = codex_limits()
    s = {"cli": "codex", "plan": "ChatGPT Plus", "cooldown_until": cooldown_until("codex", ledger)}
    if rl:
        windows = []
        for name in ("primary", "secondary"):
            w = rl.get(name) or {}
            if "used_percent" in w:
                windows.append({"window_hours": round(w.get("window_minutes", 0) / 60, 1),
                                "used_percent": w["used_percent"], "resets_at": w.get("resets_at")})
        s["windows"] = windows
        s["snapshot_age_min"] = round((now() - seen) / 60)
        # A window whose reset time has passed is refilled even if the snapshot is stale.
        for w in windows:
            if w["resets_at"] and w["resets_at"] < now():
                w["used_percent"] = 0
        s["headroom_percent"] = 100 - max((w["used_percent"] for w in windows), default=0)
    return s


def vibe_sessions(since):
    out = []
    for f in glob.glob(str(HOME / ".vibe/logs/session/*/meta.json")):
        if os.path.getmtime(f) < since:
            continue
        try:
            m = json.loads(Path(f).read_text())
        except (OSError, json.JSONDecodeError):
            continue
        st = m.get("stats") or {}
        out.append({"mtime": os.path.getmtime(f), "cost": st.get("session_cost", 0),
                    "tokens": st.get("session_total_llm_tokens", 0)})
    return out


def vibe_status(ledger):
    plan = "unknown"
    try:
        cache = json.loads((HOME / ".vibe/whoami_cache.json").read_text())
        plan = find_key(cache, "plan_name") or plan
    except (OSError, json.JSONDecodeError):
        pass
    day = vibe_sessions(now() - 86400)
    return {"cli": "vibe", "plan": f"Le Chat {plan}", "cooldown_until": cooldown_until("vibe", ledger),
            "last_24h": {"sessions": len(day), "tokens": sum(s["tokens"] for s in day),
                         "est_cost_usd": round(sum(s["cost"] for s in day), 4)}}


def agy_default_model():
    try:
        return json.loads((HOME / ".gemini/antigravity-cli/settings.json").read_text()).get("model") or "default"
    except (OSError, json.JSONDecodeError):
        return "default"


def agy_quota():
    """Live quota groups from agy's /quota slash command (no model call, 0 tokens), or None."""
    try:
        out = subprocess.run(["agy", "-p", "/quota", "--output-format", "json"],
                             capture_output=True, text=True, timeout=30).stdout
        return json.loads(out)["command"]["data"]["groups"]
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError, KeyError, TypeError):
        return None


def parse_agy_quota(groups):
    return [{"group": g["name"], "windows": [
        {"window": b["window"], "remaining_percent": round(b["remaining_fraction"] * 100, 1),
         "resets_at": datetime.fromisoformat(b["reset_time"].replace("Z", "+00:00")).timestamp()}
        for b in g["buckets"]]} for g in groups]


def agy_status(ledger):
    s = {"cli": "agy", "plan": "Google AI Pro", "cooldown_until": cooldown_until("agy", ledger)}
    groups = agy_quota()
    if groups:
        s["groups"] = parse_agy_quota(groups)
        return s
    # Fallback when /quota fails: count what this script ran in the 5h window.
    recent = [e for e in ledger if e["cli"] == "agy" and e["ts"] > now() - 5 * 3600 and e.get("tokens")]
    by_model = {}
    for e in recent:
        m = e.get("model") or agy_default_model()
        by_model[m] = by_model.get(m, 0) + e["tokens"]
    s["last_5h"] = {"runs": len(recent), "tokens_by_model": by_model}
    return s


def status():
    ledger = read_ledger()
    return [codex_status(ledger), agy_status(ledger), vibe_status(ledger)]


def print_status(rows):
    for s in rows:
        cd = s.get("cooldown_until")
        line = f"{s['cli']:5} {s['plan']:15} "
        if cd:
            line += f"COOLDOWN until {fmt_time(cd)} "
        if s["cli"] == "codex":
            for w in s.get("windows", []):
                reset = fmt_time(w["resets_at"]) if w.get("resets_at") else "?"
                line += f"{w['window_hours']:g}h {w['used_percent']:g}% used (resets {reset}); "
            if "snapshot_age_min" in s:
                line += f"snapshot {s['snapshot_age_min']}m old"
        elif s["cli"] == "agy" and "groups" in s:
            for g in s["groups"]:
                line += f"{g['group']}: " + ", ".join(
                    f"{w['window']} {w['remaining_percent']:g}% left (resets {fmt_time(w['resets_at'])})"
                    for w in g["windows"]) + "; "
        elif s["cli"] == "agy":
            u = s["last_5h"]
            per_model = ", ".join(f"{m} {t}" for m, t in u["tokens_by_model"].items()) or "0"
            line += f"last 5h via this script: {u['runs']} runs, tokens: {per_model}"
        else:
            u = s["last_24h"]
            line += f"last 24h: {u['sessions']} sessions, {u['tokens']} tokens, ~${u['est_cost_usd']}"
        print(line)


# ---- importing Claude skills into subagent prompts ----

CLAUDE = HOME / ".claude"
SKILL_DIR = Path(__file__).resolve().parent.parent
ALWAYS_IMPORT = SKILL_DIR / "always-import.txt"
NEVER_IMPORT = SKILL_DIR / "never-import.txt"
MODE_RE = re.compile(r"\b([A-Z][A-Z-]+) MODE ACTIVE \u2014 level: ([\w-]+)")
SKILL_USE_RE = re.compile(r'"name":"Skill","input":\{"skill":"([^"]+)"')



def plugin_paths():
    """{plugin name: install dir} for enabled Claude Code plugins, at their installed version."""
    try:
        installed = json.loads((CLAUDE / "plugins/installed_plugins.json").read_text())["plugins"]
        enabled = json.loads((CLAUDE / "settings.json").read_text()).get("enabledPlugins", {})
    except (OSError, json.JSONDecodeError, KeyError):
        return {}
    out = {}
    for key, entries in installed.items():
        if enabled.get(key) and entries:
            # Prefer the user-scope install; project-scope ones belong to other repos.
            entry = next((e for e in entries if e.get("scope") == "user"), entries[-1])
            out[key.split("@")[0]] = Path(entry["installPath"])
    return out


def find_skill(name, plugins):
    """Path to SKILL.md for `plugin:skill` or a bare skill name, or None."""
    if ":" in name:
        plugin, skill = name.split(":", 1)
        root = plugins.get(plugin)
        cands = [root / "skills" / skill / "SKILL.md"] if root else []
    else:
        cands = [CLAUDE / "skills" / name / "SKILL.md",
                 *map(Path, glob.glob(str(CLAUDE / "skills/synced/*" / name / "SKILL.md"))),
                 *(root / "skills" / name / "SKILL.md" for root in plugins.values())]
    return next((c for c in cands if c.is_file()), None)


def config_lines(path):
    try:
        lines = path.read_text().splitlines()
    except FileNotFoundError:
        return []
    return [l.strip() for l in lines if l.strip() and not l.lstrip().startswith("#")]


def session_skills():
    """[(skill, level)] the orchestrating Claude Code session is using, read from its transcript.

    Hook-started modes ("PONYTAIL MODE ACTIVE — level: ultra") map to plugin:plugin with their
    latest level; skills Claude invoked with the Skill tool come in as named.
    """
    sid = os.environ.get("CLAUDE_CODE_SESSION_ID")
    paths = glob.glob(str(CLAUDE / "projects/*" / f"{sid}.jsonl")) if sid else []
    if not paths:
        return []
    text = Path(paths[0]).read_text(errors="replace")
    modes = {}
    for m in MODE_RE.finditer(text):
        modes[m.group(1).lower()] = m.group(2)
    used = dict.fromkeys(SKILL_USE_RE.findall(text))
    return [(f"{n}:{n}", lvl) for n, lvl in modes.items()] + [(n, None) for n in used]


def wanted_skills(extra, plugins):
    """[(name, level, required)] in import order: always-import, then this session's, then --skill."""
    never = config_lines(NEVER_IMPORT)
    out = []
    # Silently skip plugin skills whose plugin is disabled: turning ponytail off turns it off here too.
    for n in config_lines(ALWAYS_IMPORT):
        if ":" not in n or n.split(":")[0] in plugins:
            out.append((n, None, False))
    for n, lvl in session_skills():
        bare = n.split(":")[-1]
        if not any(fnmatch.fnmatch(n, g) or fnmatch.fnmatch(bare, g) for g in never):
            out.append((n, lvl, False))
    # --skill names are explicit, so they bypass never-import and fail loudly when missing.
    out += [(n, None, True) for n in extra]
    return out


def skills_preamble(extra):
    """(preamble text, imported names): skill bodies, frontmatter stripped, to put before the task."""
    plugins = plugin_paths()
    wanted = wanted_skills(extra, plugins)
    blocks, names, missing, levels = [], [], [], {}
    for name, level, required in wanted:
        path = find_skill(name, plugins)
        if not path:
            if required:
                missing.append(name)
            continue
        if level:
            levels[path] = level
        if path in (p for _, p in names):
            continue
        names.append((name, path))
    if missing:
        raise SystemExit(f"skill not found: {', '.join(missing)} (use plugin:skill or a name under ~/.claude/skills)")
    for name, path in names:
        body = re.sub(r"\A---\n.*?\n---\n", "", path.read_text(), count=1, flags=re.S).strip()
        level = f", active level: {levels[path]}" if path in levels else ""
        blocks.append(f"--- skill: {name}{level} (its referenced files are in {path.parent}) ---\n{body}")
    if not blocks:
        return "", []
    text = ("=== Skills to follow, imported from the orchestrating Claude session. They describe how to "
            "work; slash commands and Claude-specific tools they mention may not exist for you. ===\n\n"
            + "\n\n".join(blocks) + "\n\n=== End of skills. The task follows. ===\n\n")
    return text, [n for n, _ in names]


# ---- running ----

def build_cmd(cli, prompt, edit, model, out_file):
    # agy and vibe take the prompt as the value of -p, so -p goes last.
    if cli == "codex":
        cmd = ["codex", "exec", "--json", "--skip-git-repo-check",
               "-s", "workspace-write" if edit else "read-only", "-o", str(out_file)]
        model_flag = "-m"
    elif cli == "agy":
        # agy has no headless read-only mode (plan mode denies the shell reads it relies on),
        # so read-only is asked for in the prompt.
        cmd = ["agy", "--output-format", "json"] + (["--mode", "auto"] if edit else [])
        model_flag = "--model"
        if not edit:
            prompt += AGY_READ_ONLY
    else:
        # vibe -p stops at the first tool needing approval, so read-only runs whitelist read tools.
        cmd = ["vibe", "--output", "json"] + (
            ["--auto-approve"] if edit else ["--enabled-tools", "read_file", "--enabled-tools", "grep"])
        model_flag = None
    if model and model_flag:
        cmd += [model_flag, model]
    return cmd + (["--", prompt] if cli == "codex" else ["-p", prompt])


def parse(cli, stdout, out_file):
    """Return (answer, tokens) from a CLI's machine-readable output."""
    if cli == "codex":
        answer = out_file.read_text() if out_file.exists() else ""
        tokens = 0
        for line in stdout.splitlines():
            if '"turn.completed"' in line:
                u = json.loads(line).get("usage", {})
                tokens += u.get("input_tokens", 0) + u.get("output_tokens", 0)
        return answer.strip(), tokens
    if cli == "agy":
        d = json.loads(stdout)
        if d.get("status") != "SUCCESS":
            return "", 0
        return d.get("response", "").strip(), (d.get("usage") or {}).get("total_tokens", 0)
    msgs = json.loads(stdout)
    texts = [c.get("text", "") for m in msgs if m.get("type") == "message" and m.get("role") == "assistant"
             for c in (m.get("content") or []) if c.get("type") == "text"]
    return (texts[-1].strip() if texts else ""), vibe_tokens(msgs[0].get("sessionId", "") if msgs else "")


def vibe_tokens(session_id):
    """vibe's JSON output has no usage; its session dir (suffixed with the id's first 8 chars) does."""
    if not session_id:
        return 0
    for f in glob.glob(str(HOME / f".vibe/logs/session/*_{session_id[:8]}/meta.json")):
        try:
            m = json.loads(Path(f).read_text())
        except (OSError, json.JSONDecodeError):
            continue
        if m.get("session_id") == session_id:
            return (m.get("stats") or {}).get("session_total_llm_tokens", 0)
    return 0


def run_one(cli, prompt, edit, model, cd, timeout):
    STATE.joinpath("logs").mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S") + f"-{os.getpid()}"
    log = STATE / "logs" / f"{stamp}-{cli}.log"
    out_file = STATE / "logs" / f"{stamp}-{cli}.last.txt"
    t0 = now()
    entry = {"ts": t0, "cli": cli, "model": model or (agy_default_model() if cli == "agy" else None), "edit": edit, "cwd": cd, "log": str(log)}
    try:
        p = subprocess.run(build_cmd(cli, prompt, edit, model, out_file), cwd=cd, capture_output=True,
                           text=True, timeout=timeout, stdin=subprocess.DEVNULL)
        stdout, stderr, rc = p.stdout, p.stderr, p.returncode
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
        stdout, stderr, rc = out.decode(errors="replace") if isinstance(out, bytes) else out, "", 124
    except FileNotFoundError:
        stdout, stderr, rc = "", f"{cli} not installed", 127
    log.write_text(f"$ {cli} (rc={rc})\n--- stdout\n{stdout}\n--- stderr\n{stderr}\n")
    answer, tokens = "", 0
    if rc == 0:
        try:
            answer, tokens = parse(cli, stdout, out_file)
        except (json.JSONDecodeError, AttributeError, TypeError):
            pass
    entry.update(rc=rc, secs=round(now() - t0, 1), tokens=tokens, ok=bool(answer))
    if not answer and rc != 124 and QUOTA_RE.search(stdout + stderr):
        entry["until"] = quota_reset(cli) or now() + COOLDOWN[cli]
        entry["quota_hit"] = True
    append_ledger(entry)
    return answer, entry


def quota_reset(cli):
    if cli != "codex":
        return None
    rl, _ = codex_limits()
    resets = [w.get("resets_at") for w in (rl or {}).values()
              if isinstance(w, dict) and w.get("used_percent", 0) >= 100 and w.get("resets_at")]
    return max(resets, default=None)


def usable(cli, rows):
    s = next(r for r in rows if r["cli"] == cli)
    if s.get("cooldown_until"):
        return False
    return cli != "codex" or s.get("headroom_percent", 100) >= CODEX_MIN_HEADROOM


def cmd_run(a):
    prompt = sys.stdin.read() if a.prompt == "-" else a.prompt
    preamble, imported = ("", []) if a.no_import else skills_preamble(a.skill)
    prompt = preamble + prompt
    skills_note = f" skills={','.join(imported)}" if imported else ""
    if a.cli == "auto":
        rows = status()
        order = [c for c in a.prefer.split(",") if c in CLIS]
        candidates = [c for c in order if usable(c, rows)]
        if not candidates:
            print("[all subagent CLIs are cooling down or out of quota; run `status`]")
            return 2
    else:
        candidates = [a.cli]
    for cli in candidates:
        answer, e = run_one(cli, prompt, a.edit, a.model if a.cli != "auto" else None, a.cd, a.timeout)
        state = "ok" if e["ok"] else ("QUOTA" if e.get("quota_hit") else f"FAILED rc={e['rc']}")
        if answer:
            print(answer)
        print(f"[{cli} {state} {e['secs']}s tokens={e['tokens']}{skills_note} log={e['log']}]")
        if e["ok"]:
            return 0
        if not e.get("quota_hit"):
            return 124 if e["rc"] == 124 else 1
    return 2


def selftest():
    assert find_key({"a": [{"b": {"rate_limits": {"x": 1}}}]}, "rate_limits") == {"x": 1}
    assert QUOTA_RE.search("Error: RESOURCE_EXHAUSTED (429)")
    assert QUOTA_RE.search("You've hit your usage limit")
    assert not QUOTA_RE.search("context window too long")
    agy = '{"status":"SUCCESS","response":"hi\\n","usage":{"total_tokens":42}}'
    assert parse("agy", agy, None) == ("hi", 42)
    assert parse("agy", '{"status":"ERROR"}', None) == ("", 0)
    q = parse_agy_quota([{"name": "Gemini Models", "buckets": [
        {"window": "5h", "remaining_fraction": 0.9832, "reset_time": "2026-10-19T06:11:57Z"}]}])
    assert q[0]["windows"][0]["remaining_percent"] == 98.3 and q[0]["windows"][0]["resets_at"] == 1792390317
    vibe = json.dumps([{"type": "message", "role": "user", "content": [{"type": "text", "text": "q"}]},
                       {"type": "message", "role": "assistant", "content": [{"type": "text", "text": "a1"}]},
                       {"type": "message", "role": "assistant", "content": [{"type": "text", "text": "a2"}]}])
    assert parse("vibe", vibe, None) == ("a2", 0)
    codex = build_cmd("codex", "p", False, "m1", Path("o"))
    assert codex[-4:] == ["-m", "m1", "--", "p"] and "read-only" in codex
    agy = build_cmd("agy", "p", True, "gemini-3.8-flash-high", None)
    assert agy[-2:] == ["-p", "p"] and "--mode" in agy and "--model" in agy
    assert build_cmd("agy", "p", False, None, None)[-1] == "p" + AGY_READ_ONLY
    vibe = build_cmd("vibe", "p", False, "x", None)
    assert vibe[-2:] == ["-p", "p"] and "--model" not in vibe and "read_file" in vibe
    os.environ.pop("CLAUDE_CODE_SESSION_ID", None)  # no orchestrator: always-import only
    pre, names = skills_preamble([])
    assert ("ponytail:ponytail" in names) == ("ponytail" in plugin_paths())
    assert "\nname: ponytail" not in pre  # frontmatter stripped
    try:
        skills_preamble(["no-such-skill-xyz"])
        raise AssertionError("missing --skill must fail loudly")
    except SystemExit:
        pass
    text = ('"PONYTAIL MODE ACTIVE \u2014 level: full" ... "PONYTAIL MODE ACTIVE \u2014 level: ultra" '
            '{"name":"Skill","input":{"skill":"superpowers:test-driven-development"}} ')
    assert [(m.group(1), m.group(2)) for m in MODE_RE.finditer(text)][-1] == ("PONYTAIL", "ultra")
    assert SKILL_USE_RE.findall(text) == ["superpowers:test-driven-development"]
    print("selftest ok")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    st = sub.add_parser("status")
    st.add_argument("--json", action="store_true")
    r = sub.add_parser("run")
    r.add_argument("cli", choices=CLIS + ("auto",))
    r.add_argument("prompt", help="prompt text, or - to read stdin")
    r.add_argument("--edit", action="store_true", help="allow file edits and commands in --cd")
    r.add_argument("--cd", default=os.getcwd(), help="working directory for the subagent")
    r.add_argument("--model", help="model override (codex, agy; ignored by vibe and auto)")
    r.add_argument("--prefer", default="codex,agy,vibe", help="auto mode order")
    r.add_argument("--timeout", type=int, default=1800)
    r.add_argument("--skill", action="append", default=[],
                   help="Claude skill to import into the prompt (plugin:skill or name); repeatable")
    r.add_argument("--no-import", action="store_true", help="send the bare prompt: no imported skills at all")
    sub.add_parser("selftest")
    a = ap.parse_args()
    if a.cmd == "status":
        rows = status()
        print(json.dumps(rows, indent=1)) if a.json else print_status(rows)
        return 0
    if a.cmd == "selftest":
        selftest()
        return 0
    return cmd_run(a)


if __name__ == "__main__":
    sys.exit(main())
