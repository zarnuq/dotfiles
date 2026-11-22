---
name: zq-refactor
description: Use when restructuring code without changing behaviour (extract, merge, move, rename across files), or when migrating a schema, data format, API, config or dependency.
---

# zq refactor

Change structure, not behaviour, with a check run before and after.

## Refactor

1. **Pin behaviour first.** Find or write the check (tests, a script, a captured output) and run it before touching anything.
2. **Keep features out.** A refactor that also changes behaviour can't be verified as either.
3. **One boundary at a time.** Move one ownership boundary per step, and keep each intermediate state building and passing.
4. **Preserve contracts.** Public interfaces, error behaviour, ordering and compatibility stay as they were unless the user scoped a change.
5. **No growth.** No new dependency, config or abstraction unless correctness needs it.
6. **Run the same check after.** Done when it matches and the requested structure exists.

## Migration

1. **Map first.** Every reader and writer of the thing, its current shape, and how long old and new must coexist.
2. **Forward and back.** Write the rollback path before the forward one.
3. **Expand, migrate, verify, contract.** Add the new form alongside the old, move the data or callers, verify both paths, and only then remove the old one.
4. **Never destroy implicitly.** Deleting the old data or columns is its own step, and the user authorises it explicitly. Stop after the stage you were asked for.
5. **Retry-safe.** Steps are idempotent, and a partial failure is visible rather than silent.
