---
name: zq-plan
description: Use when a request is a feature, project or multi-file change where something non-trivial about what to build is still open, or when asked to plan, design or brainstorm before coding, or to carry out a plan already agreed.
---

# zq plan

From a vague request to an agreed design, then a plan, then execution.

## 0. Do you need this at all?

Ask what you actually know. If everything that matters is in the request ("make the icon cornflower blue"), skip this skill: do it and say what you did.

## 1. Look before you ask

Read what the user pointed at and the code it touches until you can explain how it works today and what the change would touch. Never ask what the repo or the conversation already answers, or reopen something already decided.

## 2. Understand the want

- Get them describing first: what it's for and why. Offering a menu of guesses steers them.
- One specific question at a time, tied to what they've said.
- Play it back in short chunks: what you understood as theirs, and what you filled in as your proposal, with the reason. End each chunk by asking what's wrong or missing.
- A default you choose silently is one they can't reject: say your defaults out loud.

## 3. Lay out the approaches

Two or three ways to build it, each with what it trades off, and your pick first with one sentence why. Run the zq ladder on each: the cheapest approach that holds usually wins. They choose.

## 4. Size it, then write it down

- **Small change:** a short design in the chat (intent, the approach chosen, constraints, non-goals), a line or two each.
- **Project:** the same points written as a doc that a capable builder could plan from without coming back to ask. Save it to a file only if they want one, and ask where.
- **Several independent projects:** say so, agree an order, and take them one at a time.

Approval covers only what they saw. If the work grows mid-task, stop, say so, and step up a size.

## 5. The plan

- Map the files first: what each one created or changed is responsible for. Follow the repo's existing layout.
- A task is the smallest unit with its own check that a reviewer could accept or reject on its own. Fold setup and config into the task that needs them.
- Each step is one action with a checkable result: the test with its assertions, the exact signature and file, or the command plus the output that means it passed.
- A plan decides what the builder can't decide alone. "Handle edge cases" decides nothing. A plan longer than the code it describes has written the code.
- Self-check before handing it over: every requirement maps to a task, names stay consistent across tasks, and each failure mode the design implies has a test.

## 6. Executing

- Work the steps in order. Run each check and compare it with the expected output.
- The code is wrong: use `zq-debug`, never patch the output to match. The plan is wrong: make the smallest change that still meets the design, and note it as `Ruling: <what> because <why>`.
- Don't stop to ask "should I continue?" between tasks. Stop only for something irreversible or destructive, a security-sensitive action, anything outside the repo (push, publish, deploy), or a plan so broken every path is a guess.
- A task is done when its checks ran and passed in this session, not when the diff looks right.
- At the end: run the full check, then a `zq-review` pass over the whole change.
