---
name: zq-tdd
description: Use when building a feature or fixing a bug where behaviour can be pinned by a test first, or when asked for TDD or test-first work.
---

# zq tdd

Test first, watch it fail, write the least code that passes, then tidy.

## The loop

1. **Red.** Write one test for the next behaviour. Name the production change that would make it fail before writing it.
2. **Watch it fail** for the expected reason, an assertion and not an import error. A test that passes before the code exists tests nothing: fix the test.
3. **Green.** Write the minimum code that passes. Hardcoding is fine until the next test forces the general case.
4. **Watch it pass**, and the rest of the suite with it.
5. **Refactor** with the tests green. No new behaviour in this step.
6. Repeat for the next behaviour.

Code written before its test: delete it and redo it from the test, rather than keeping it as "reference".

## Good tests

- One behaviour per test. An "and" in the name means split it.
- The name says what the code does, not `test1`.
- Assert on real behaviour, never on what a mock returns.
- Understand a dependency's side effects before mocking it. Mock at the boundary (network, clock, filesystem), not your own code.
- Test-only helpers live in test code, never in production classes.

## Fitting the repo

Use the repo's test runner. No runner and the logic is small: one assert-based self-check file is enough, per the zq core. Don't add a framework for one test.

Bug fix: the first test reproduces the bug. Then follow `zq-debug`'s fix step.
