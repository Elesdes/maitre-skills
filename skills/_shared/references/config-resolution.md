# Resolving configuration

Shared by every `maitre-skills` skill.

Config lives under a `maitre` key inside the agent folder's `settings.local.json`, so it coexists
with the agent's own settings instead of fighting them.

## Lookup order

`PROJECT_DIR` is `$CLAUDE_PROJECT_DIR` when set, else the root of the current git repository, else
the current directory. First file that contains a `maitre` key wins:

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
for d in "$PROJECT_DIR/.claude" "$PROJECT_DIR/.opencode" "$PROJECT_DIR/.agents" \
         "$HOME/.claude" "$HOME/.config/maitre"; do
  f="$d/settings.local.json"
  [ -f "$f" ] && grep -q '"maitre"' "$f" && { echo "CONFIG: $f"; cat "$f"; break; }
done
```

Project scope beats user scope, so one user-level file can point every project at the same vault
and a project can still override it. Read the `maitre` object; ignore every sibling key, they belong
to the agent.

## Keys

| Key | Meaning | Default |
|---|---|---|
| `vault` | absolute path to the Maître vault (the folder that contains `_maitre/`) | **required** |
| `projectSlug` | the project's slug in the vault (`proj-<slug>`) | basename of `PROJECT_DIR`, lowercased, non-alphanumerics → `-` |
| `recallLimit` | maximum number of nodes `maitre-recall` returns | `7` |
| `autoPropose` | `true`: write proposals to `<vault>/inbox/`. `false`: print them only | `true` |

If no `vault` resolves, stop and tell the user to create `<agent folder>/settings.local.json` from
`docs/templates/settings.local.example.json` in their `maitre-skills` clone, or to re-run
`install.sh`. Never fall back to a guessed path.

A `~` at the start of `vault` means `$HOME`. Any other relative path is an error: say so and stop.

## Locating the shared directory

References live in `_shared/`, a sibling of each skill's directory. Resolve it relative to the skill
you are executing (`../_shared/references/...`). If that path does not exist, locate it:

```bash
for d in "$PROJECT_DIR"/.claude/skills/_shared "$PROJECT_DIR"/.opencode/skills/_shared \
         "$PROJECT_DIR"/.agents/skills/_shared "$HOME"/.claude/skills/_shared; do
  [ -d "$d" ] && { echo "SHARED: $d"; break; }
done
```
