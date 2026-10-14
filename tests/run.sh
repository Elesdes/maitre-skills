#!/usr/bin/env bash
# Tests for install.sh: copy and --link modes into .claude, .opencode and .agents,
# no-overwrite behaviour, config writing and merging, vault version warnings.
# Works in a temp dir that is deleted on exit; the repository is never modified.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALL="$ROOT/install.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/maitre-skills-tests.XXXXXX")
export TMPDIR="$WORK/tmp"   # keeps install.sh's settings backups inside $WORK
mkdir -p "$TMPDIR"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "  ok    $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $*"; }
check() { local msg=$1; shift; if "$@"; then ok "$msg"; else fail "$msg"; fi; }
jqtest() { jq -e "$@" > /dev/null; }

fake_vault() { # $1 dir, $2 VERSION content ("" = no VERSION file)
  mkdir -p "$1/_maitre" "$1/inbox" "$1/wiki"
  [[ -n "$2" ]] && printf '%s\n' "$2" > "$1/_maitre/VERSION"
  return 0
}

new_project() { mkdir -p "$WORK/projects/$1"; echo "$WORK/projects/$1"; }

# run install.sh in project $1 with stdin $2, remaining args passed through
run_install() {
  local proj=$1 input=$2; shift 2
  (cd "$proj" && printf '%b' "$input" | bash "$INSTALL" "$@")
}

all_files_installed() { # $1 agent dir path
  local f
  while IFS= read -r f; do
    [[ -f "$1/$f" ]] || { echo "    missing $1/$f"; return 1; }
  done < <(cd "$ROOT" && find commands skills -type f)
}

clone_checksum() { (cd "$ROOT" && find commands skills -type f -print0 | sort -z | xargs -0 sha256sum); }
clone_checksum > "$WORK/clone.before"
clone_untouched() { clone_checksum | cmp -s - "$WORK/clone.before"; }

VAULT_OK="$WORK/vault-ok";      fake_vault "$VAULT_OK" "1.0.0"
VAULT_NEW="$WORK/vault-2";      fake_vault "$VAULT_NEW" "2.0.0"
VAULT_OLD="$WORK/vault-0";      fake_vault "$VAULT_OLD" "0.9.0"
VAULT_NONE="$WORK/vault-none";  fake_vault "$VAULT_NONE" ""

# ---------------------------------------------------------------------------
echo "1. Copy mode into each agent folder"
for agent in .claude .opencode .agents; do
  p=$(new_project "copy${agent}")
  out=$(run_install "$p" "" --vault "$VAULT_OK" "$agent")
  check "$agent: every command and skill file copied" all_files_installed "$p/$agent"
  check "$agent: nothing is a symlink" bash -c "[[ -z \$(find '$p/$agent' -type l) ]]"
  check "$agent: config has vault" grep -q "\"vault\": \"$VAULT_OK\"" "$p/$agent/settings.local.json"
  check "$agent: config has default slug" grep -q "\"projectSlug\": \"copy-${agent#.}\"" "$p/$agent/settings.local.json"
  check "$agent: compatible vault reported" grep -q 'is schema 1.0.0 (compatible' <<<"$out"
  check "$agent: CLAUDE.md snippet printed" grep -q 'run /maitre-recall' <<<"$out"
  if command -v jq >/dev/null 2>&1; then
    check "$agent: config is valid JSON" jqtest '.maitre.recallLimit == 7 and .maitre.autoPropose == true' "$p/$agent/settings.local.json"
  fi
  out=$(run_install "$p" "" --vault "$VAULT_OK" "$agent")
  check "$agent: re-run copies nothing" bash -c "! grep -qE '^  (copied|linked) ' <<<\"\$1\"" _ "$out"
  check "$agent: re-run keeps existing config" grep -q 'already exists in' <<<"$out"
done
check "project CLAUDE.md is never written" bash -c "[[ -z \$(find '$WORK/projects' -name CLAUDE.md -o -name AGENTS.md) ]]"

# ---------------------------------------------------------------------------
echo "2. No-overwrite behaviour"
p=$(new_project "overwrite")
run_install "$p" "" --vault "$VAULT_OK" .claude > /dev/null
target="$p/.claude/skills/maitre-recall/SKILL.md"
printf 'my local edit\n' > "$target"
run_install "$p" "n\n" --no-config .claude > "$WORK/ow-n.out"
check "answering n keeps a modified file" grep -qx 'my local edit' "$target"
check "the prompt names the file" grep -q "maitre-recall/SKILL.md already exists and differs" "$WORK/ow-n.out"
run_install "$p" "" --no-config .claude > /dev/null
check "closed stdin defaults to no" grep -qx 'my local edit' "$target"
run_install "$p" "y\n" --no-config .claude > /dev/null
check "answering y restores the file" cmp -s "$ROOT/skills/maitre-recall/SKILL.md" "$target"

# ---------------------------------------------------------------------------
echo "3. --link mode into each agent folder"
for agent in .claude .opencode .agents; do
  p=$(new_project "link${agent}")
  run_install "$p" "" --link --vault "$VAULT_OK" --slug linked "$agent" > /dev/null
  check "$agent: skills are links to the clone" \
    bash -c "[[ -L '$p/$agent/skills/maitre-fix' && \$(readlink '$p/$agent/skills/maitre-fix') == '$ROOT/skills/maitre-fix' ]]"
  check "$agent: _shared is linked" test -L "$p/$agent/skills/_shared"
  check "$agent: commands are links" test -L "$p/$agent/commands/maitre-learn.md"
  check "$agent: every file reachable" all_files_installed "$p/$agent"
  check "$agent: --slug honoured" grep -q '"projectSlug": "linked"' "$p/$agent/settings.local.json"
  out=$(run_install "$p" "" --link --vault "$VAULT_OK" "$agent")
  check "$agent: link re-run is idempotent" bash -c "! grep -qE '^  (copied|linked) ' <<<\"\$1\"" _ "$out"
done

p=$(new_project "link-to-copy")
run_install "$p" "" --link --no-config .claude > /dev/null
run_install "$p" "n\n" --no-config .claude > /dev/null
check "copy over a link asks first (n keeps the link)" test -L "$p/.claude/skills/maitre-recall"
check "copy never writes through a link into the clone" clone_untouched
run_install "$p" "$(printf 'y\\n%.0s' {1..20})" --no-config .claude > /dev/null
check "answering y replaces links with copies" bash -c "[[ ! -L '$p/.claude/skills/maitre-recall' && -f '$p/.claude/skills/maitre-recall/SKILL.md' ]]"

# ---------------------------------------------------------------------------
echo "4. Config writing"
p=$(new_project "prompted")
run_install "$p" "$VAULT_OK\n" .claude > /dev/null
check "vault path read from the prompt" grep -q "\"vault\": \"$VAULT_OK\"" "$p/.claude/settings.local.json"

p=$(new_project "noconfig")
run_install "$p" "" --no-config --vault "$VAULT_OK" .claude > /dev/null
check "--no-config writes no settings" test ! -e "$p/.claude/settings.local.json"

p=$(new_project "keep-existing")
mkdir -p "$p/.claude"
printf '{\n  "maitre": { "vault": "%s", "projectSlug": "mine" }\n}\n' "$VAULT_OK" > "$p/.claude/settings.local.json"
cp "$p/.claude/settings.local.json" "$WORK/keep.before"
run_install "$p" "" --vault "$VAULT_NEW" .claude > /dev/null
check "existing maitre block is left byte-identical" cmp -s "$WORK/keep.before" "$p/.claude/settings.local.json"

p=$(new_project "merge")
mkdir -p "$p/.claude"
printf '{\n  "permissions": { "allow": ["Bash(make test)"] }\n}\n' > "$p/.claude/settings.local.json"
run_install "$p" "" --vault "$VAULT_OK" .claude > "$WORK/merge.out"
if command -v jq >/dev/null 2>&1; then
  # shellcheck disable=SC2016  # $v is a jq variable, not a shell one
  check "jq merge keeps sibling keys and adds maitre" \
    jqtest --arg v "$VAULT_OK" '.permissions.allow[0] == "Bash(make test)" and .maitre.vault == $v' "$p/.claude/settings.local.json"
  check "merge backup kept outside the project" bash -c "ls '$TMPDIR'/maitre-settings.local.json.* >/dev/null"
else
  echo "  skip  jq not installed: merge path not tested"
fi

p=$(new_project "merge-nojq")
mkdir -p "$p/.claude" "$WORK/nojq-bin"
for tool in bash sh basename cat cmp cp dirname find grep head ln mkdir mktemp rm readlink sed sort tr; do
  ln -sf "$(command -v "$tool")" "$WORK/nojq-bin/$tool"
done
printf '{ "permissions": {} }\n' > "$p/.claude/settings.local.json"
(cd "$p" && PATH="$WORK/nojq-bin" bash "$INSTALL" --vault "$VAULT_OK" .claude < /dev/null > "$WORK/nojq.out")
check "without jq the file is left alone" grep -qx '{ "permissions": {} }' "$p/.claude/settings.local.json"
check "without jq an example block is written next to it" grep -q '"maitre"' "$p/.claude/settings.local.maitre.example.json"

p=$(new_project "escape")
run_install "$p" "" --vault '/tmp/we"ird\path' .claude > /dev/null
if command -v jq >/dev/null 2>&1; then
  check "quotes and backslashes in the vault path are escaped" \
    jqtest '.maitre.vault == "/tmp/we\"ird\\path"' "$p/.claude/settings.local.json"
fi

p=$(new_project "relative")
if run_install "$p" "" --vault "relative/path" .claude > /dev/null 2>&1; then
  fail "relative vault path is rejected"
else
  ok "relative vault path is rejected"
fi

# ---------------------------------------------------------------------------
echo "5. Vault VERSION checks"
for case in "$VAULT_NEW:2.0.0" "$VAULT_OLD:0.9.0"; do
  v=${case%%:*}; ver=${case##*:}
  p=$(new_project "ver-$ver")
  out=$(run_install "$p" "" --vault "$v" .claude)
  check "warns on incompatible VERSION $ver" grep -q "WARNING: vault schema $ver is incompatible" <<<"$out"
done
p=$(new_project "ver-missing")
out=$(run_install "$p" "" --vault "$VAULT_NONE" .claude)
check "warns when VERSION is missing" grep -q 'WARNING: .*_maitre/VERSION not found' <<<"$out"
p=$(new_project "ver-ok-minor")
fake_vault "$WORK/vault-1-9" "1.9.3"
out=$(run_install "$p" "" --vault "$WORK/vault-1-9" .claude)
check "accepts a newer minor (1.9.3)" grep -q 'is schema 1.9.3 (compatible' <<<"$out"

# ---------------------------------------------------------------------------
echo "6. Contract hygiene"
check "requires_schema is declared once, in vault-contract.md" \
  bash -c "[[ \$(grep -rlF 'requires_schema: \"' '$ROOT/skills' '$ROOT/commands' '$ROOT/install.sh' | wc -l) -eq 1 ]]"
check "skills never name a wiki/ write" bash -c "! grep -rnE '(write|Write)[^.]*<vault>/wiki' '$ROOT/skills' '$ROOT/commands'"
for s in "$ROOT"/skills/maitre-*/SKILL.md; do
  check "$(basename "$(dirname "$s")") has name and description" \
    bash -c "sed -n '1,5p' '$s' | grep -q '^name: ' && sed -n '1,5p' '$s' | grep -q '^description: '"
done

# ---------------------------------------------------------------------------
echo ""
echo "passed: $PASS  failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
