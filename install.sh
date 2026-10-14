#!/usr/bin/env bash
# Install maitre-skills into a project's agent folder (.claude, .opencode or .agents).
# Needs only bash and coreutils; uses jq when present to merge an existing settings file.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cd /path/to/project && /path/to/maitre-skills/install.sh [options] <agent-dir>

Arguments:
  <agent-dir>      Agent folder in this project: .claude, .opencode or .agents.
                   commands/ and skills/ are installed underneath it, and a
                   "maitre" block is written to <agent-dir>/settings.local.json.

Options:
  --link           Symlink instead of copying, so `git pull` in maitre-skills
                   updates this project.
  --no-config      Do not touch <agent-dir>/settings.local.json.
  --vault <path>   Absolute path to your Maître vault (otherwise you are asked).
  --slug <slug>    Project slug in the vault (default: this folder's name).
  -h, --help       Show this help.

Re-running is safe: identical files are skipped and you are asked before any
existing file is replaced.
EOF
}

MODE="copy"
NO_CONFIG=0
VAULT=""
SLUG=""
DEST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --link) MODE="link"; shift ;;
    --no-config) NO_CONFIG=1; shift ;;
    --vault) VAULT="${2:-}"; [[ -n "$VAULT" ]] || { echo "Error: --vault needs a path." >&2; exit 1; }; shift 2 ;;
    --slug) SLUG="${2:-}"; [[ -n "$SLUG" ]] || { echo "Error: --slug needs a value." >&2; exit 1; }; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) [[ -z "$DEST" ]] || { echo "Error: only one <agent-dir> expected." >&2; exit 1; }; DEST="$1"; shift ;;
  esac
done
[[ -n "$DEST" ]] || { usage >&2; exit 1; }
DEST="${DEST%/}"

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONTRACT="$SRC/skills/_shared/references/vault-contract.md"
[[ -f "$CONTRACT" ]] || { echo "Error: $SRC is not a maitre-skills checkout." >&2; exit 1; }

# Prompts read fd 3, a copy of the caller's stdin, so loops that redirect
# stdin cannot swallow the answers.
exec 3<&0

# Ask a yes/no question; default No (also when stdin is closed).
ask() {
  local answer=""
  printf "%s [y/N] " "$1"
  read -r answer <&3 || true
  case "$answer" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------------------
# Files

install_file() { # copy one file, asking before replacing a different one
  local from=$1 to=$2 label=$3
  if [[ -e "$to" || -L "$to" ]]; then
    if [[ ! -L "$to" ]] && cmp -s "$from" "$to"; then
      echo "  unchanged  $label"
      return 0
    fi
    if ! ask "$label already exists and differs. Overwrite?"; then
      echo "  kept       $label"
      return 0
    fi
    rm -f "$to"
  fi
  mkdir -p "$(dirname "$to")"
  cp "$from" "$to"
  echo "  copied     $label"
}

install_item() { # one command file or one skill directory
  local rel=$1 from="$SRC/$1" to="$DEST/$1"
  if [[ "$MODE" == link ]]; then
    if [[ -L "$to" && "$(readlink "$to")" == "$from" ]]; then
      echo "  unchanged  $DEST/$rel -> $from"
      return 0
    fi
    if [[ -e "$to" || -L "$to" ]]; then
      if ! ask "$DEST/$rel already exists. Replace it with a link to $from?"; then
        echo "  kept       $DEST/$rel"
        return 0
      fi
      rm -rf "$to"
    fi
    mkdir -p "$(dirname "$to")"
    ln -s "$from" "$to"
    echo "  linked     $DEST/$rel -> $from"
    return 0
  fi

  # copy mode: never write through a symlink left by an earlier --link install
  if [[ -L "$to" ]]; then
    if ! ask "$DEST/$rel is a link to $(readlink "$to"). Replace it with a copy?"; then
      echo "  kept       $DEST/$rel"
      return 0
    fi
    rm -f "$to"
  fi
  if [[ -d "$from" ]]; then
    local f
    while IFS= read -r f; do
      install_file "$SRC/$f" "$DEST/$f" "$DEST/$f"
    done < <(cd "$SRC" && find "$rel" -type f | sort)
  else
    install_file "$from" "$to" "$DEST/$rel"
  fi
}

echo "Installing maitre-skills into $DEST/ ($MODE mode) from $SRC"
for f in "$SRC"/commands/*.md; do
  install_item "commands/$(basename "$f")"
done
for d in "$SRC"/skills/*/; do
  install_item "skills/$(basename "$d")"
done

# ---------------------------------------------------------------------------
# Config

json_escape() { local s=${1//\\/\\\\}; printf '%s' "${s//\"/\\\"}"; }

default_slug() {
  basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

existing_vault() { # vault value of an existing maitre block, if any
  sed -n 's/^[[:space:]]*"vault"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' "$1" | head -n 1
}

TARGET="$DEST/settings.local.json"
if [[ "$NO_CONFIG" -eq 0 ]]; then
  echo ""
  if [[ -f "$TARGET" ]] && grep -q '"maitre"' "$TARGET"; then
    echo "Config: a maitre block already exists in $TARGET - left untouched."
    [[ -n "$VAULT" ]] || VAULT=$(existing_vault "$TARGET")
  else
    if [[ -z "$VAULT" ]]; then
      printf "Absolute path to your Maître vault (empty to skip): "
      read -r VAULT <&3 || true
    fi
    if [[ -z "$VAULT" ]]; then
      echo "Config: skipped. Create $TARGET from docs/templates/settings.local.example.json later."
    else
      [[ "$VAULT" == "~"* ]] && VAULT="$HOME${VAULT:1}"
      if [[ "$VAULT" != /* ]]; then
        echo "Error: the vault path must be absolute: $VAULT" >&2
        exit 1
      fi
      VAULT="${VAULT%/}"
      SLUG="${SLUG:-$(default_slug)}"
      block=$(printf '{\n    "vault": "%s",\n    "projectSlug": "%s",\n    "recallLimit": 7,\n    "autoPropose": true\n  }' \
        "$(json_escape "$VAULT")" "$(json_escape "$SLUG")")
      mkdir -p "$DEST"
      if [[ ! -f "$TARGET" ]]; then
        printf '{\n  "maitre": %s\n}\n' "$block" > "$TARGET"
        echo "Config: wrote $TARGET"
      elif command -v jq >/dev/null 2>&1 \
           && merged=$(jq --argjson m "$block" '. + {maitre: $m}' "$TARGET" 2>/dev/null); then
        # Back up outside the project so the copy can never be committed.
        backup=$(mktemp "${TMPDIR:-/tmp}/maitre-settings.local.json.XXXXXX")
        cp "$TARGET" "$backup"
        printf '%s\n' "$merged" > "$TARGET"
        echo "Config: merged a maitre block into $TARGET (backup: $backup)"
      else
        printf '{\n  "maitre": %s\n}\n' "$block" > "$DEST/settings.local.maitre.example.json"
        echo "Config: $TARGET exists and could not be merged automatically (jq missing or invalid JSON)."
        echo "  -> paste the \"maitre\" block from $DEST/settings.local.maitre.example.json into it,"
        echo "     then delete that example file."
      fi
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Vault version check (warn only)

ver_cmp() { # prints -1, 0 or 1 comparing semver-ish $1 and $2
  local IFS=.
  local -a a b
  read -r -a a <<<"$1"
  read -r -a b <<<"$2"
  local i x y
  for i in 0 1 2; do
    x=${a[i]:-0}; y=${b[i]:-0}
    x=${x//[!0-9]/}; y=${y//[!0-9]/}
    x=${x:-0}; y=${y:-0}
    if ((10#$x < 10#$y)); then echo -1; return; fi
    if ((10#$x > 10#$y)); then echo 1; return; fi
  done
  echo 0
}

satisfies() { # $1 version, $2 range like ">=1.0.0 <2.0.0"
  local clause op want c
  for clause in $2; do
    op=${clause%%[0-9]*}; want=${clause#"$op"}
    c=$(ver_cmp "$1" "$want")
    case "$op" in
      ">=") [[ $c -ge 0 ]] || return 1 ;;
      ">")  [[ $c -gt 0 ]] || return 1 ;;
      "<=") [[ $c -le 0 ]] || return 1 ;;
      "<")  [[ $c -lt 0 ]] || return 1 ;;
      "=="|"=") [[ $c -eq 0 ]] || return 1 ;;
      *) return 1 ;;
    esac
  done
}

RANGE=$(sed -n 's/^requires_schema:[[:space:]]*"\(.*\)"/\1/p' "$CONTRACT")
echo ""
if [[ -z "$VAULT" ]]; then
  echo "Vault check: skipped (no vault path known)."
elif [[ ! -f "$VAULT/_maitre/VERSION" ]]; then
  echo "WARNING: $VAULT/_maitre/VERSION not found. Is $VAULT a Maître vault?"
  echo "         The skills will refuse to run until the vault path is right."
else
  version=$(tr -d '[:space:]' < "$VAULT/_maitre/VERSION")
  if satisfies "$version" "$RANGE"; then
    echo "Vault check: $VAULT is schema $version (compatible with $RANGE)."
  else
    echo "WARNING: vault schema $version is incompatible with these skills ($RANGE)."
    echo "         Update the vault (_maitre/update.sh <tag>) or maitre-skills (git pull),"
    echo "         whichever is older. The skills will refuse to run until then."
  fi
fi

# ---------------------------------------------------------------------------
cat <<EOF

Optional, not applied: add this line to the project's CLAUDE.md or AGENTS.md

  At the start of each task, run /maitre-recall (or the maitre-recall skill) and follow its confirmed results; at the end, run /maitre-learn.

Keep $TARGET out of git: it holds the absolute path to your private vault.
Next: run /maitre-bootstrap once in this project, then /maitre-review in the vault.
EOF
