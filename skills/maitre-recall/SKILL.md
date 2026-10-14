---
name: maitre-recall
description: Recall how this developer works before starting a task - pulls a short ranked list of confirmed preferences, conventions, decisions and known error fixes from the Maître vault, with warnings for contradictions and stale fixes. Read-only. Use at the start of a task, when the user asks what their conventions are, or invokes /maitre-recall.
allowed-tools: Bash(cat *), Bash(ls *), Bash(grep *), Bash(find *), Bash(head *), Bash(git rev-parse *), Bash(date *), Read, AskUserQuestion
---

# maitre-recall

Print the handful of vault nodes that matter for this task, then apply the confirmed ones.

This skill owns the **pipeline only**. The algorithm is the vault's `_maitre/workflow/retrieval.md`;
follow it literally. This skill writes nothing.

## Inputs

| Input | Meaning | Default |
|---|---|---|
| `task` | what the user is about to do | the user's current request; ask if there is none |

## Step 0 — Config

Follow `../_shared/references/config-resolution.md` to resolve `vault`, `projectSlug`, `recallLimit`.

## Step 1 — Contract

Follow `../_shared/references/vault-contract.md`: Step A (version check), then Step B with the
`maitre-recall` row. Stop if either fails.

## Step 2 — Recall

Apply `<vault>/_maitre/workflow/retrieval.md` from its first step to its Output section, with
`projectDir` = `PROJECT_DIR`, `projectSlug` and `recallLimit` from config, and today's date.

- Read only what retrieval.md tells you to read: frontmatter via grep, then the few surviving files.
- Read project manifests from `PROJECT_DIR`, never from the vault.
- Never load the whole vault.

## Step 3 — Print

Print the output block exactly as retrieval.md's Output section shapes it: the context line, the
ranked bullets with ids, the warnings, the pending drafts. Nothing else, unless a result needs its
body (a decision's rationale, an error's fix) for the task: then read that one file and quote the
relevant lines.

If nothing matches, print the context line and `No matching nodes.` Suggest `maitre-bootstrap` if
the vault has no `proj-<projectSlug>` node.

## Step 4 — Apply

- Treat confirmed results as the user's working rules for this task, below the user's explicit
  instructions in this conversation and the project's own `CLAUDE.md` / `AGENTS.md`.
- Never apply pending drafts.
- On a contradiction warning that this task actually hits, follow retrieval.md's guidance; if it
  says to ask, ask per `../_shared/references/asking-the-user.md`.
