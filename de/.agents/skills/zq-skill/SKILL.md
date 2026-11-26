---
name: zq-skill
description: Use when creating, editing, merging or trimming a skill (SKILL.md), a subagent definition, or an AGENTS.md/CLAUDE.md instruction section.
---

# zq skill

A skill is a reusable technique, not the story of how one problem got solved. Write the smallest text that changes behaviour, and prove it does.

## Where things go (this setup)

- Always-on rules: `de/.agents/AGENTS.md`. Every CLI loads it, on every turn, so keep it tight.
- On-demand skills: `de/.agents/skills/<name>/SKILL.md`. Every CLI sees `~/.agents/skills`. Claude needs a per-skill link in `~/.claude/skills`.
- Large or rarely used libraries: a router skill plus unregistered skills, like `ctf` and `redteam`.
- Claude subagents: `de/.claude/agents/<name>.md`.

## Test first

1. **Baseline.** Run the scenario without the skill: a fresh `claude -p` or a subagent. Note what goes wrong, word for word.
2. **Write** only what fixes those failures. Nothing for hypothetical cases.
3. **Rerun** the same scenario with the skill and confirm the behaviour changed.
4. **Close loopholes.** Find the new excuse, plug it, rerun.

`scripts/run.sh <dir> "<prompt>"` runs one headless session in a scratch fixture dir and saves `<dir>.jsonl` next to it; `FLAGS=--safe-mode` gives the no-customization baseline. `scripts/trace.py <dir>.jsonl` prints the main-thread tool calls in order plus turns and cost, so "did it invoke X before the first Edit" is one read. Compare cost too: a rule that fixes behaviour but triples the calls is a new failure. `scripts/suite.sh <new-dir>` reruns the whole zq regression (every scenario, zq and baseline, about $4); a new AGENTS.md rule gets a scenario in `fixtures.py` and its check in `check.py`.

An edit to an existing skill gets the same test.

## Description

It says when to use the skill: trigger conditions and symptoms, starting with "Use when…". Never summarise the workflow in it, or the agent follows the summary and skips the body. It costs listing budget every session, so keep it to one or two lines.

## Match the form to the failure

| Baseline failure | Write |
|---|---|
| Knows the rule, breaks it under pressure | A firm rule, plus the excuses it uses and why they're wrong |
| Output has the wrong shape | The shape itself: its parts, in order. Don't write a "don't" list |
| Leaves out a required part | A required slot in the template it fills in |
| Should depend on a condition | A conditional keyed to something observable |

Avoid "unless it matters" clauses: they reopen the negotiation. A real exception becomes its own conditional.

## Body

Answer first, then rules, then one example. Split rarely used reference material into files next to `SKILL.md` and link them, so they load only when needed. Credit the upstream source if you adapted one.
