---
name: zq-review
description: Use when asked to review a diff, PR, branch or file, or to check work before calling it done. Also when someone else's review comes back and has to be answered.
---

# zq review

Review the change, not the author. One line per finding: location, problem, fix. The best outcome is a shorter diff that does the same job.

## Getting the diff

Use what the user hands over (a pasted diff, a file, a PR number). Running `git diff` or `git log` needs their OK this session, like any git command.

## Two passes, one list

1. **Correctness.** Broken behaviour, missed callers, unhandled failure paths, security holes, races. Grep every caller of a changed function before trusting the diff.
2. **Complexity.** What can be deleted or replaced: reinvented stdlib, an unneeded dependency, an abstraction with one user, config nobody sets, code a few files over already does.

## Format

`<file>:L<line>: <tag> <problem>. <fix>.` Leave out the file for a single-file review.

| Tag | For |
|---|---|
| `bug:` | will break: wrong result, crash, data loss |
| `risk:` | works but fragile: race, missing guard, swallowed error |
| `sec:` | security issue. Write it as a full paragraph: what is exposed, how, and the fix |
| `delete:` | dead code, unused flexibility, speculative feature. Replacement: nothing |
| `stdlib:` | hand-rolled thing the stdlib ships. Name the function |
| `native:` | code or a dependency doing what the platform does. Name the feature |
| `reuse:` | duplicates a helper already in this repo. Name the path |
| `yagni:` | one-implementation interface, one-caller layer, unread config |
| `shrink:` | same logic, fewer lines. Show the shorter form |
| `nit:` | style or naming the author may ignore |
| `q:` | a real question, not a disguised suggestion |

Examples:
- `L42: bug: user is null when .find() misses. Guard before .email.`
- `L12-38: stdlib: 27-line slug builder. re.sub plus str.lower, 2 lines.`
- `api.py:L88: yagni: BaseRepository with one subclass. Inline it until a second exists.`

Order findings `sec`, `bug`, `risk`, then the cuts by size, then `nit`/`q`. End with `net: -<N> lines possible.` Nothing found: `Lean and correct. Ship.`

Never flag the one runnable check (an assert self-test or a single test file) as bloat. That's the minimum, not excess.

Exact line numbers and symbol names in backticks. No praise, no hedging, no restating what a line does. A fix the author can't act on ("consider refactoring") isn't a fix.

Reviews only: it applies nothing unless asked.

For a large change you made yourself in this session, offer a fresh reviewer: a `general-purpose` subagent given only the diff and the requirements, never the session history, so it judges the work rather than your reasoning.

## When review comes back to you

1. Read all of it before changing anything.
2. Check each item against the code. Reviewers miss context too.
3. A suggestion to "do it properly" for something nothing calls: grep for callers, and if there are none, propose deleting it instead.
4. Wrong for this codebase: push back with the code or test that shows why.
5. Fix in order: security and breakage first, quick fixes next, restructuring last. Run the check after each.

No "great point" or "you're absolutely right". State what changes, or why it doesn't.
