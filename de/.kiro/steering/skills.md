---
inclusion: always
---

# Skills

Skills are not preloaded. When the user names one, read only that file:
`~/.agents/skills/<name>/SKILL.md`. Do not list or search `~/.agents/skills` unless
the user explicitly asks for the list, and
never read a skill the user did not name. Kiro agents live in `~/.kiro/agents`,
which is unrelated to skills.

# How to work

- Act on the most likely reading of the request. Ask at most one question, and
  only when the guesses lead to different, hard-to-undo results.
- Short requests mean short work: do the obvious thing, then report in a few lines.
