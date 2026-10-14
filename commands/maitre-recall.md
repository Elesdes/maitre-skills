---
description: Recall this developer's confirmed preferences, conventions, decisions and known fixes for the current task from the Maître vault.
argument-hint: [task description]
allowed-tools: Bash(cat *), Bash(ls *), Bash(grep *), Bash(find *), Bash(head *), Bash(git rev-parse *), Bash(date *), Read, AskUserQuestion, Skill
---

Invoke the `maitre-recall` skill and follow it end to end.

- task: `$ARGUMENTS` (default: the user's current request)

If there is no task in `$ARGUMENTS` and none in the conversation, ask what the task is instead of guessing.
