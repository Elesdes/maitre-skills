---
description: Look up an error in the Maître vault before debugging, and propose a new error node once a fix is verified.
argument-hint: [error text]
allowed-tools: Bash(cat *), Bash(ls *), Bash(grep *), Bash(find *), Bash(head *), Bash(mkdir *), Bash(git rev-parse *), Bash(date *), Read, Write, AskUserQuestion, Skill
---

Invoke the `maitre-fix` skill and follow it end to end.

- error: `$ARGUMENTS` (default: the most recent error in this session)

If there is no error text in `$ARGUMENTS` and none in the conversation, ask for it instead of guessing.
