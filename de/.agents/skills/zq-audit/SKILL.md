---
name: zq-audit
description: Use when asked to audit a whole repo or directory for bloat or over-engineering, or "what can I delete from this". Not for reviewing a single diff, which is zq-review.
---

# zq audit

The complexity pass of `zq-review`, run over the whole tree instead of a diff. Report only; change nothing.

## Hunt for

- dependencies the stdlib or platform already ships
- interfaces with one implementation, factories with one product, wrappers that only delegate
- files that export one thing used once
- dead flags, config nobody sets, unread options
- hand-rolled stdlib
- helpers that duplicate one already elsewhere in the repo

Before reporting a `delete:`, search the whole tree for the symbol with `rg`, including tests, fixtures, and string or dynamic references (`getattr`, reflection, config keys). If it's found anywhere, it isn't dead.

## Output

One line per finding, biggest cut first, using `zq-review`'s complexity tags:

`<tag> <what to cut>. <replacement>. [path:line]`

End with `net: -<N> lines, -<M> deps possible.` Nothing to cut: `Lean already. Ship.`

Out of scope: correctness, security and performance. Note any you trip over in one line at the end and suggest a `zq-review` pass.
