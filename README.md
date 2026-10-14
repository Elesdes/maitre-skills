# maitre-skills

[![GitHub License](https://img.shields.io/github/license/AluciTech/maitre-skills)](LICENSE)
[![Vault schema](https://img.shields.io/badge/vault%20schema-%3E%3D1.0.0%20%3C2.0.0-blue)](skills/_shared/references/vault-contract.md)
[![CI](https://github.com/AluciTech/maitre-skills/actions/workflows/ci.yml/badge.svg)](.github/workflows/ci.yml)

> [!WARNING]
> This project is in early development and is not yet ready for production use.

## Overview

This project is the project-side half of [Maître](https://github.com/AluciTech/maitre): four
commands and skills you install into each project's `.claude/`, `.opencode/` or `.agents/` folder.
Its goal is to let the coding agent in that project **recall** how you work from your Maître vault
before a task, and **propose** what it learned afterwards, without ever writing trusted knowledge
itself.

The skills hold pipeline steps only. Every rule (node schema, recall algorithm, what deserves a
proposal, how to scrub secrets, where writes may go) is read at runtime from your vault's
`_maitre/` folder, so updating the vault updates every project at once. Before doing anything, each
skill checks that the vault's `_maitre/VERSION` is within `>=1.0.0 <2.0.0` and stops otherwise.

| Command / skill | What it does | Writes |
|---|---|---|
| `/maitre-bootstrap` | reads manifests, lockfiles, `CLAUDE.md`/`AGENTS.md`, README and git log; proposes `project`, `stack` and `language` nodes | drafts in `<vault>/inbox/` |
| `/maitre-recall [task]` | prints the ≤ 7 most relevant confirmed nodes, ranked, with ids and warnings (contradictions, stale or version-mismatched fixes) | nothing |
| `/maitre-learn` | at the end of a task, proposes observations, preferences, conventions, decisions, scrubbed, with evidence | drafts in `<vault>/inbox/` (or prints them) |
| `/maitre-fix [error]` | looks the error up in the vault first; once a new fix is verified, proposes an `error` node | drafts in `<vault>/inbox/` (or prints them) |

Every command is a thin trigger for the skill of the same name, so agents without slash commands
(Codex) use the skills directly: "run maitre-recall for this task".

### Human in the loop

These skills can only **propose**. They write to `<vault>/inbox/` and `<vault>/raw/`, never to
`<vault>/wiki/`, and recall applies only nodes you have confirmed. Drafts appear in recall as
"pending" and are never applied. To turn a proposal into a rule, open an agent inside the vault and
run `maitre-review`, which asks you about each draft in turn: accept, edit, reject, merge, or
supersede. Set `autoPropose: false` if you prefer that the skills print proposals instead of
writing them at all.

## Setup

### Requirements

- `git` and `bash`. `jq` is used if present to merge into an existing `settings.local.json`;
  without it the installer writes the block to a side file for you to paste.
- A Maître vault: see [AluciTech/maitre](https://github.com/AluciTech/maitre) (three commands).
- An agent: [Claude Code](https://docs.anthropic.com/en/docs/claude-code),
  [OpenCode](https://opencode.ai/) or [Codex](https://github.com/openai/codex).

Nothing else: no runtime, no package manager, no registry.

### Recommended Setup

Two commands: clone once, then install into each project.

```bash
git clone https://github.com/AluciTech/maitre-skills ~/tools/maitre-skills   # pin with: git -C ~/tools/maitre-skills checkout vX.Y.Z
cd /path/to/project && ~/tools/maitre-skills/install.sh .claude          # or .opencode / .agents
```

The installer:

- copies `commands/` and `skills/` into the agent folder, skipping identical files and **asking
  before replacing** any file that differs;
- asks for your vault path and writes the `maitre` block to `<agent folder>/settings.local.json`
  (merging into an existing file, keeping your other keys; an existing `maitre` block is left alone);
- checks the vault's `_maitre/VERSION` and warns if it is missing or incompatible;
- prints, but never applies, an optional line for your project's `CLAUDE.md` / `AGENTS.md`.

| Option | Effect |
|---|---|
| `--link` | symlink instead of copying, so `git -C ~/tools/maitre-skills pull` updates every linked project |
| `--no-config` | leave `settings.local.json` alone |
| `--vault <path>` | give the vault path instead of being asked |
| `--slug <slug>` | project slug in the vault (default: the project folder's name) |

Re-running it is safe. Keep `settings.local.json` out of git: it holds the path to your private vault.

#### Manual install

No script needed. From your `maitre-skills` clone, copy two folders into the project's agent folder:

```bash
cp -R ~/tools/maitre-skills/commands ~/tools/maitre-skills/skills /path/to/project/.claude/
```

Then create `/path/to/project/.claude/settings.local.json` (or add the `maitre` key to it):

```json
{
  "maitre": {
    "vault": "/absolute/path/to/your/maitre-vault",
    "projectSlug": "my-project",
    "recallLimit": 7,
    "autoPropose": true
  }
}
```

Use `.opencode/` or `.agents/` instead of `.claude/` for OpenCode or Codex.

### Configuration

Resolved from the first file containing a `maitre` key, in this order:
`<project>/.claude/`, `<project>/.opencode/`, `<project>/.agents/`, `~/.claude/`, `~/.config/maitre/`
(`settings.local.json` in each). A user-level file can point every project at the same vault.

| Key | Meaning | Default |
|---|---|---|
| `vault` | absolute path to your Maître vault | **required** |
| `projectSlug` | the project's slug in the vault (`proj-<slug>`) | project folder name |
| `recallLimit` | maximum nodes returned by recall | `7` |
| `autoPropose` | write proposals to the inbox (`true`) or only print them (`false`) | `true` |

Template: [`docs/templates/settings.local.example.json`](docs/templates/settings.local.example.json).
Details: [`skills/_shared/references/config-resolution.md`](skills/_shared/references/config-resolution.md).

## Usage

Once per project, introduce it to the vault, then review the drafts in the vault:

```
/maitre-bootstrap
```

Then, for each task:

```
/maitre-recall add pagination to the orders endpoint
... work ...
/maitre-learn
```

and whenever something breaks:

```
/maitre-fix ValidationError: 1 validation error for Order total field required
```

### Worked example

In `acme-api`, before a bug fix:

```
> /maitre-fix ValidationError: 1 validation error for Order total field required

Error match: [[err-pydantic-field-required]] (exact) — Give the field a default: total: Optional[Decimal] = None
⚠ version mismatch: [[err-pydantic-field-required]] applies to pydantic >=1.8 <2.0; acme-api pins 2.9.2
⚠ stale fix: [[err-pydantic-field-required]] verified_on 2025-06-03 (> 12 months)
```

The agent treats the old fix as a hypothesis only, finds that Pydantic 2 needs a different fix,
makes the failing test pass, and then proposes:

```
supersede · error · [[err-pydantic2-field-required]] · Pydantic 2 'Field required' on Optional fields
Run maitre-review in the vault to confirm it.
```

Nothing changes in your trusted notes until you accept that draft in `maitre-review`.

### How the pieces fit

| Layer | Lives in |
|---|---|
| Trigger and arguments | `commands/<name>.md` (thin, delegates to the skill) |
| Pipeline steps | `skills/<name>/SKILL.md` |
| Config resolution | `skills/_shared/references/config-resolution.md` |
| Vault contract: version range, files each skill reads, write boundary pointer | `skills/_shared/references/vault-contract.md` |
| Asking the user (structured tool or numbered list) | `skills/_shared/references/asking-the-user.md` |
| Schema, recall, proposing, scrubbing, write boundary | **your vault**: `<vault>/_maitre/` (never copied here) |

### Testing

```bash
bash tests/run.sh
```

Installs into throwaway projects for `.claude`, `.opencode` and `.agents` in both copy and `--link`
mode, and checks the no-overwrite prompts, the config written or merged, and the warnings for a
missing or incompatible vault `VERSION`. CI also runs `shellcheck`.

### Roadmap (out of scope for v1)

- Session hooks that run recall and learn automatically.
- A Claude Code plugin marketplace entry.
- A derived graph index or embeddings for recall.
- Integration with an Obsidian kanban / ticket workflow (we use [dotpm](https://dotpm.pm) today; Maître stays agnostic).

## License

This project is licensed under the Apache License (Version 2.0).

See the [LICENSE](LICENSE) file for details.

## AI Usage Transparency

This project uses AI tools such as Claude Code to assist with development.
For more details, see the [AI Usage Disclosure](AI_USAGE.md) file.
