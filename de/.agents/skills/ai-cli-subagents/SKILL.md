---
name: ai-cli-subagents
description: Use when work can be handed to Miles's other AI subscriptions running as headless CLI subagents — Codex (ChatGPT Plus), Antigravity `agy` (Google AI Pro, Gemini and Claude models) and Mistral Vibe (Le Chat Free) — to save Claude's usage and context. Trigger whenever the user says "ask codex", "ask gemini/agy", "use mistral/vibe", "fan this out", "run these in parallel", "use my other subscriptions", "get a second opinion", or asks how much quota or usage is left on those CLIs; also use it for bulk or mechanical work (big file or log reading, codebase sweeps, boilerplate, tests, independent subtasks) where delegating beats doing it in Claude's context, even if no CLI is named.
---

# AI CLI subagents

Claude orchestrates; the other subscriptions do the legwork. Every delegated task saves Claude tokens twice: the subagent reads the files instead of Claude, and only its short final answer comes back. Claude still owns understanding the request, splitting the work, writing each prompt, checking the result and talking to the user.

All runs go through one script (stdlib Python, no setup):

```sh
python3 <skill-dir>/scripts/delegate.py status            # headroom per CLI; costs no tokens
python3 <skill-dir>/scripts/delegate.py run codex "<prompt>" --cd <repo>
python3 <skill-dir>/scripts/delegate.py run agy   "<prompt>" --cd <repo> --edit
python3 <skill-dir>/scripts/delegate.py run auto  "<prompt>" --prefer agy,vibe,codex
python3 <skill-dir>/scripts/delegate.py run codex - --cd <repo> --edit --skill superpowers:test-driven-development   # prompt on stdin
```

`run` prints the subagent's final answer, then one footer line: `[cli ok|QUOTA|FAILED secs tokens log=<path>]`. Exit codes: 0 ok, 1 failed, 2 quota hit (the script records a cooldown), 124 timeout. Use `-` as the prompt to pipe a long prompt over stdin.

## The three subscriptions

| CLI | Plan | Models | What limits it | Good at |
|---|---|---|---|---|
| `codex` | ChatGPT Plus | GPT-6.1 (`-m` to override) | 5h window + weekly window; `status` shows % used and reset times from codex's own logs. That snapshot refreshes after every codex run, and a window past its reset time counts as refilled | Code edits, bug fixes, refactors, writing and running tests, code review |
| `agy` | Google AI Pro | `gemini-3.8-flash-{low,medium,high}`, `claude-sonnet-4-6`, `claude-opus-4-6-thinking`, `gpt-oss-120b-medium` (`agy models`) | Two quota groups (Gemini; Claude and GPT), each with a 5h and a weekly limit. `status` shows % left and reset times live from agy's `/quota` command (0 tokens), falling back to this script's last-5h runs if that fails; a quota error starts a cooldown | Gemini Flash: fast bulk reading, summarising big files and logs, codebase sweeps. Claude Opus 4.6: hard reasoning that would otherwise burn Claude's own quota |
| `vibe` | Le Chat **Free** | Mistral Medium 3.5 | Tightest limits of the three; `status` shows 24h sessions, tokens and estimated cost | Small, well-scoped jobs: one-file edits, summaries, boilerplate, quick second opinions |

Run `status` before fanning out several tasks, and again whenever one hits quota. The three report usage in different units, so pick like this:

- **Coding, edits, tests:** codex while both its windows are under ~70% used, otherwise agy.
- **Reading, explaining, summarising, searching:** agy. Its default model is Gemini 3.8 Flash (High), and the Gemini group has its own 5h and weekly limits. That leaves codex's weekly window for code.
- **Tiny, non-private jobs, or a third parallel worker:** vibe. Its free quota is the smallest, so don't give it long agentic runs.
- **No preference, or "whichever has room":** `run auto`. Its default order is `codex,agy,vibe`; pass `--prefer` to change it.
- When an agy model hits quota, try the other quota group with `--model`, e.g. `claude-sonnet-4-6`, before giving up on agy.

One large codex `--edit` run can use several percent of the 5h window and run past the 1800s timeout. Split big refactors into one run per module or directory.

## Deciding what to delegate

Delegate when the work is self-contained and its result can be described in a few lines: reading large files or logs and reporting what matters, searching a codebase, mechanical multi-file edits, writing tests, drafting boilerplate, reviewing a diff, or several independent subtasks at once.

Keep the work in Claude when the conversation context it needs is too large or subtle to write down (see the next section for what to pass), when the user asked for Claude's own judgment, when it is a one-line change (writing the prompt costs more than doing it), or when it touches secrets.

These are outside providers (OpenAI, Google, Mistral). Do not send `.env` files, keys, tokens or credentials. Miles's own repos are fine on codex and agy, which run on paid plans. Le Chat Free may use inputs for training, so send vibe only code that is already public or throwaway, unless Miles agrees.

## Writing the prompt

The subagent starts cold. It sees only the prompt and its `--cd` directory: no conversation, no memory, none of what Claude has read or learned. Most bad delegated results come from missing context, not a weak model. The prompt has to carry everything the subagent cannot find in the files itself.

Split context by where it lives:

- **Lives in the files** (code, configs, docs, logs on disk): point to it with exact paths, functions and line numbers. Don't paste it. The subagent reads files with its own quota, and pasting costs Claude's.
- **Lives only in this conversation**: paste it, because nothing else carries it. That covers what the user actually wants and why, decisions already made, approaches tried and ruled out, exact error text and command output, and facts Claude found out (for example "the bug only shows with `--json`" or "`foo()` is also called from `bar.py:88`").
- **Machine and repo facts** that would mislead a fresh agent. For example: Gentoo with Nix home-manager and runit, so not systemd. Say which repo convention file to follow (`AGENTS.md`, `CLAUDE.md`), the test command, and "match the surrounding code style".

Use this template. Write every heading; put `none` under one that doesn't apply, so a gap is a decision rather than an accident:

```text
GOAL: <one or two sentences: the outcome, and why the user wants it>
CONTEXT: <conversation-only facts: user intent, decisions made, things ruled out, exact errors/output, findings so far>
FILES: <paths, functions, line numbers to read or change; follow <repo>/AGENTS.md if present>
CONSTRAINTS: <what not to touch, style to match, platform facts, read-only or not>
DONE WHEN: <the command that proves it works, and its expected result>
REPLY WITH: <plain text, no markdown links, at most N lines: exactly the fields Claude needs next>
```

Before sending, check the prompt from the subagent's side. Could a capable engineer who just walked in do this with only this text and the repo? If they would have to ask "which file?", "what did the user mean?", "what have you tried?" or "how do I know it worked?", answer that in the prompt first. If you aren't sure of a path, line number or command, check it (a `grep` or `ls` is cheap) or mark it as a guess so the subagent verifies it. A confident wrong fact misleads more than a missing one. When no command can prove the result (GUI behaviour, boot-time bugs), say so under DONE WHEN, ask for the closest static check, and verify it yourself afterwards, for example with the ydotool skill. When fanning out, give each subagent the shared context too, not just its slice: parallel workers can't see each other's prompts.

Prompts longer than a few lines go over stdin, so the shell doesn't mangle quotes:

```sh
python3 <skill-dir>/scripts/delegate.py run codex - --cd ~/repo --edit <<'PROMPT'
GOAL: ...
PROMPT
```

**Example.** The user has spent ten minutes with Claude on a flaky test, then says "get codex to fix it".

Weak: `fix the flaky test in tests/test_sync.py`

Strong:
```text
GOAL: Make tests/test_sync.py::test_retry pass reliably. It fails about 1 run in 5, and the user wants CI green without masking a real bug.
CONTEXT: Failure is "AssertionError: expected 3 calls, got 2" (full output below). We traced it to sync.retry() using time.monotonic() deltas with a 0.1s budget, and CI is slow. Ruled out: test ordering (it fails alone too). The user does NOT want a bigger sleep or a retry decorator on the test.
<pasted failing output>
FILES: src/sync.py retry() ~L40-75; tests/test_sync.py test_retry. Follow AGENTS.md.
CONSTRAINTS: Don't change the public retry() signature. Inject the clock or freeze time; no new dependencies.
DONE WHEN: `pytest tests/test_sync.py -q --count 50` (pytest-repeat is installed) passes 50/50.
REPLY WITH: plain text, at most 8 lines: root cause, files changed, test result.
```

## Importing your skills

Subagents don't load Claude's skills, plugins or hooks, so `run` makes them adopt the orchestrator's skills automatically. It pastes each skill's body, with frontmatter stripped, ahead of the task, from three sources in this order:

1. **`<skill-dir>/always-import.txt`**: imported on every run. It lists `ponytail:ponytail`. A plugin skill is skipped when its plugin is disabled in Claude Code.
2. **This Claude session**: `run` reads the transcript at `$CLAUDE_CODE_SESSION_ID`. It imports every hook-started mode (`PONYTAIL MODE ACTIVE — level: ultra` becomes `ponytail:ponytail`, sent with its active level) and every skill Claude has invoked with the Skill tool. So if Claude loaded `superpowers:test-driven-development` or `kubernetes-skill` for this task, the subagent gets it too, with no flag needed. Skills matching a glob in `<skill-dir>/never-import.txt` are dropped: ones that only work inside Claude Code (artifacts, config, browser), or that orchestrate Claude subagents and the user (brainstorming, skill-creator, this skill).
3. **`--skill <name>`**: adds a skill the session hasn't loaded, as `plugin:skill` or a bare name under `~/.claude/skills`. An explicit `--skill` overrides `never-import.txt`, and an unknown name fails before anything is sent.

The footer lists what was sent (`skills=ponytail:ponytail,caveman:caveman`), so check it rather than assuming. Imported text counts against the subagent's quota, not Claude's: ponytail plus caveman is about 2.5k tokens per run. Use `--no-import` for a quick question where the rules would only add tokens. To stop a skill from ever being forwarded, add it to `never-import.txt`.

## Running

- **Read-only** is the default. codex runs `-s read-only` and vibe gets only `read_file` and `grep`, so both are enforced. agy has no headless read-only mode: Miles's agy settings default to auto, and `--mode plan` makes it deny the shell commands it reads files with. So for agy, read-only rests on the prompt alone. The script appends a do-not-modify line to read-only agy prompts; run `git status` afterwards if it matters.
- **`--edit`** lets the subagent change files and run commands inside `--cd`: codex `-s workspace-write`, agy `--mode auto`, vibe `--auto-approve`.
- **Parallel:** launch each `run` as its own Bash call with `run_in_background`. The harness notifies you as each one finishes, so don't write wait or poll loops; read each answer when its notification arrives. Two `--edit` agents must never share a working tree. Give each one its own directory or git worktree (`git worktree add ../wt-<task>`), then merge the results.
- **`auto`** tries CLIs in `--prefer` order. It skips any CLI in cooldown, and codex when either window has less than 10% left. It moves to the next CLI on a quota error.

## Checking the result

Check results cheaply: `git diff --stat`, then run the tests or the build. Read the log named in the footer only when a run failed or the answer looks wrong. Tail it first: logs hold the full transcript and are large.

| Exit | Meaning | Next step |
|---|---|---|
| 2 | Quota hit; cooldown recorded | Run `status`, then pick another CLI or use `auto` |
| 1 | Other failure, or empty answer | `tail -40 <log>`. Missing login means Miles must run the CLI once interactively |
| 124 | Timeout (default 1800s, `--timeout`) | Split the task smaller |

State lives in `~/.local/state/ai-cli-subagents/`: `ledger.jsonl` holds one line per run, including cooldowns, and `logs/` holds the full transcripts. Run `python3 <skill-dir>/scripts/delegate.py selftest` after editing the script.
