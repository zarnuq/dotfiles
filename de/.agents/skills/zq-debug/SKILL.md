---
name: zq-debug
description: Use when something fails, behaves unexpectedly, regressed, or breaks only sometimes, and the cause isn't already proven. Before proposing any fix.
---

# zq debug

No fix before a root cause. A fix without one is a guess, and a guess that seems to work hides the real bug.

## 1. Look

- Read the whole error: stack trace, line numbers, codes. Separate what you observed from what you're inferring.
- Reproduce it reliably. Can't? Gather more data; don't guess.
- What changed? Recent edits, dependency or config changes, environment differences. Reading `git log`/`git diff` needs the user's OK.
- Several components (script calls service calls DB)? Log what enters and leaves each boundary, run once, and find where it breaks before reading deeper.
- Bad value deep in a call stack: trace it back to where it was born. Fix there, not where it surfaced.

## 2. Compare

Find something similar that works, in this repo or the docs, and list every difference, however small.

## 3. Hypotheses

List them with the cheapest check that rules each one out, cheapest first. Test one at a time with the smallest possible change. Didn't confirm it? Revert it and take the next hypothesis; don't stack fixes.

Name a root cause only with the log line, output or test that proves it, and cite it.

## 4. Fix

1. Write down the rule the report implies, not just its example. "`f('90')` should be 90" implies "a bare number means seconds", which also covers `'1m30'`. Turn the reproduction plus two or three other inputs of that rule into a failing check: a test if the repo has them, else an assert script.
2. Fix the root cause at the layer that owns the wrong behaviour. One guard in the shared function beats one per caller, so grep the callers.
3. Run the check plus the nearest wider tests. No cleanup or renames riding along.

Three failed fixes in a row: stop. That's usually a wrong assumption about the design, not a fourth bug. Say so and rethink with the user.

If the evidence really points outside the code (timing, environment, an external service), say what you checked, then add handling plus logging that will catch it next time.

Asked only to investigate: report the cause and the proof, and change nothing.
