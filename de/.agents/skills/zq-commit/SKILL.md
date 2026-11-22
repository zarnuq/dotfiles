---
name: zq-commit
description: Use when asked to write a commit message, or for /zq-commit. Writes the message only.
---

# zq commit

Write the message only. Staging, committing and amending are git commands, which need the user's OK this session.

## Subject

`<type>(<scope>): <imperative summary>`. The scope is optional.

- Types: `feat` `fix` `refactor` `perf` `docs` `test` `chore` `build` `ci` `style` `revert`. A breaking change adds `!` after the type or scope.
- Imperative mood: "add", "fix", "remove".
- 50 characters if you can, 72 at most, no trailing period. Match the repo's existing capitalisation; check recent subjects if the user allows `git log`.

## Body

Skip it when the subject says everything. Add one for a non-obvious why, a breaking change, a migration note or a linked issue. Wrap at 72, use `-` bullets, and put `Closes #42` / `Refs #17` at the end.

Always write a body for breaking changes, security fixes, data migrations and reverts. Future debuggers need it.

## Never

"This commit…", "I", "we", "now", restating the file name the scope already gives, or emoji unless the repo uses them. Add an AI-attribution trailer only when the user's instructions or the session's attribution rules ask for one.

## Output

The message in a code block, ready to paste.

```
fix(quickshell): stop OSD timer firing after hide

The timer kept its last interval after the OSD hid, so a second
volume key within 2s re-hid the new OSD immediately.
```
