---
name: zq-debt
description: Use when asked what shortcuts or deferrals are marked in a codebase, "zq debt", "list the shortcuts", or what was left to do later.
---

# zq debt

Every deliberate zq shortcut carries a `zq: <ceiling>, <upgrade path>` comment. This collects them into one ledger so a deferral can't quietly become permanent. Older code may still use `ponytail:` markers; collect those too.

## Scan

```
rg -n --hidden -g '!.git' '(#|//|/\*|--|;) ?(zq|ponytail):' .
```

`rg` already skips gitignored paths (`node_modules`, build output). The comment-prefix match keeps prose that only mentions the convention out of the ledger. Add the prefix your language uses if it's missing.

## Output

One row per marker, grouped by file:

`<file>:<line>: <what was simplified>. ceiling: <limit>. upgrade: <trigger>.`

A marker with no upgrade path or trigger gets a `no-trigger` tag: those are the ones that rot.

End with `<N> markers, <M> no-trigger.` None found: `No zq debt.`

Report only. Write the ledger to a file only if asked.
