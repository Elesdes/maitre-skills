---
name: maitre-learn
description: At the end of a task, turn what the developer said and did into draft proposals for the Maître vault - observations, preferences, conventions, decisions - scrubbed of secrets and written to the vault's inbox/ for human review (or only printed when autoPropose is false). Never writes trusted knowledge. Use when a task is done, when the user says "remember this" or "learn from this", or invokes /maitre-learn.
allowed-tools: Bash(cat *), Bash(ls *), Bash(grep *), Bash(find *), Bash(head *), Bash(mkdir *), Bash(git rev-parse *), Bash(git log *), Bash(git diff *), Bash(date *), Read, Write, AskUserQuestion
---

# maitre-learn

Propose what this task taught about how the developer works. Proposals are drafts for the human to
review in the vault with `maitre-review`; nothing here becomes a rule on its own.

This skill owns the **pipeline only**. What counts as a proposal, its shape and its scrubbing are
defined by the vault's `_maitre/workflow/proposing.md` and `_maitre/workflow/scrubbing.md`.

## Inputs

| Input | Meaning | Default |
|---|---|---|
| `focus` | optional hint ("the testing setup we agreed on") | everything in this session |

## Step 0 — Config

Follow `../_shared/references/config-resolution.md`: `vault`, `projectSlug`, `autoPropose`.

## Step 1 — Contract

Follow `../_shared/references/vault-contract.md`: Step A, then Step B with the `maitre-learn` row.

## Step 2 — Gather signals

From this session only: the user's explicit statements and corrections, choices made between
alternatives with a reason, patterns you applied that the user accepted, and the diff of the task
(`git diff`, recent `git log`) when it shows a habit. Note for each: the date, `projectSlug`, and the
smallest excerpt that proves it.

## Step 3 — Classify and dedupe

For each signal, apply `proposing.md`: observation or rule, which type, which scope, which
confidence, and its *search before proposing* step against `<vault>/wiki/` and `<vault>/inbox/`.
Drop what `proposing.md` says not to propose. Respect its volume limit.

## Step 4 — Scrub

Apply `scrubbing.md` to every field and excerpt. Drop any proposal that the scrubbing rules say to drop.

## Step 5 — Write or print

Build each proposal from `<vault>/_maitre/templates/<type>.md` and the shape `proposing.md` gives.

- `autoPropose: true`: write each to `<vault>/inbox/` with the filename `proposing.md` and
  `node-schema.md` define, and any longer excerpt to `<vault>/raw/`. Write nowhere else
  (`../_shared/references/vault-contract.md`, Step C). Never overwrite an existing file: if the name
  is taken, append evidence to that draft as `proposing.md` describes.
- `autoPropose: false`: write nothing; print each proposal's path and full content.

## Step 6 — Report

One line per proposal: `new|update|supersede · <type> · [[<id>]] · <title>`. Then one line telling
the user to run `maitre-review` in the vault. If nothing qualified, say so in one line.
