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
