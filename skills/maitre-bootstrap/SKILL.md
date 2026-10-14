---
name: maitre-bootstrap
description: Introduce a project to the Maître vault - reads what the project already contains (manifests, lockfiles, CLAUDE.md/AGENTS.md, README, recent git log) and proposes project, stack and language nodes as drafts in the vault's inbox/. Use once per project after installing maitre-skills, when recall finds no project node, or when the user invokes /maitre-bootstrap.
allowed-tools: Bash(cat *), Bash(ls *), Bash(grep *), Bash(find *), Bash(head *), Bash(mkdir *), Bash(git rev-parse *), Bash(git log *), Bash(git remote *), Bash(date *), Read, Write, AskUserQuestion
---

# maitre-bootstrap

Describe this project to the vault as draft context nodes, for the human to confirm with
`maitre-review`.

This skill owns the **pipeline only**. Node shapes come from the vault's `_maitre/schema/` and
`_maitre/templates/`; what may be proposed comes from `_maitre/workflow/proposing.md`.

## Step 0 — Config

Follow `../_shared/references/config-resolution.md`: `vault`, `projectSlug`, `autoPropose`.

## Step 1 — Contract

Follow `../_shared/references/vault-contract.md`: Step A, then Step B with the `maitre-bootstrap` row.

## Step 2 — Read the project

From `PROJECT_DIR`, read only what is needed, first ~200 lines of each:

- the manifests and lockfiles that retrieval.md's language detection lists, plus their dependency names
  and resolved versions;
- `CLAUDE.md`, `AGENTS.md`, `README*` (purpose, explicit rules);
- `git log --oneline -n 30` (commit message style), `git remote get-url origin` (strip any credentials).

Never read `.env*`, secrets files or anything `scrubbing.md` forbids writing.

## Step 3 — Compare with the vault

For the project, each language and each notable stack (frameworks and major libraries, not every
dependency), check whether `<vault>/wiki/` or `<vault>/inbox/` already has the node
(`proj-<projectSlug>`, `lang-<slug>`, `stack-<slug>`), per `proposing.md`'s *search before proposing*.

- missing → `proposal: new`;
- present → propose an `update` only if this project adds something (a `used_in` link, a marker).

Explicit rules found in `CLAUDE.md` / `AGENTS.md` are **not** copied as conventions:
`proposing.md` says not to propose what the project already enforces. Mention them in the
`project` node's body instead, one line each, so recall can find the project's own rule file.

## Step 4 — Confirm the batch

Show the list (type, id, title, new/update) and ask once per
`../_shared/references/asking-the-user.md`: write all, pick some, or none.

## Step 5 — Write or print

Scrub per `scrubbing.md`. Build each node from `<vault>/_maitre/templates/<type>.md`. Write to
`<vault>/inbox/` only (or print when `autoPropose` is `false`), exactly as `maitre-learn` Step 5
describes.

## Step 6 — Report

One line per proposal, then: "Run `maitre-review` in the vault to confirm them; recall will use them
once confirmed."
