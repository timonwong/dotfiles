#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPL="$ROOT/.chezmoiscripts/run_onchange_after_10_sync-skimi.sh.tmpl"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

command -v rsync >/dev/null 2>&1 || {
    echo "SKIP: rsync not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skimi-sync-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
mkdir -p "$HOME/.config/chezmoi"
export XDG_CONFIG_HOME="$HOME/.config"

cat >"$HOME/.config/chezmoi/chezmoi.toml" <<'EOF'
[data]
platform = "darwin"
skipNix = false
nowledgeMemManaged = false
EOF

SOURCE_ROOT="$TMP_ROOT/source"
mkdir -p \
    "$SOURCE_ROOT/.chezmoiscripts" \
    "$SOURCE_ROOT/.chezmoitemplates/shell" \
    "$SOURCE_ROOT/private_dot_config/skimi/skills/local-skill"

cp "$TMPL" "$SOURCE_ROOT/.chezmoiscripts/run_onchange_after_10_sync-skimi.sh.tmpl"
cp "$ROOT/.chezmoitemplates/shell/source_nix_env.sh" "$SOURCE_ROOT/.chezmoitemplates/shell/source_nix_env.sh"
cp "$ROOT/private_dot_config/skimi/skills.yaml.tmpl" "$SOURCE_ROOT/private_dot_config/skimi/skills.yaml.tmpl"
printf '%s\n' 'local skill' >"$SOURCE_ROOT/private_dot_config/skimi/skills/local-skill/SKILL.md"

RENDERED_V1="$TMP_ROOT/skimi-sync-v1.sh"
RENDERED_V2="$TMP_ROOT/skimi-sync-v2.sh"
chezmoi execute-template --config "$HOME/.config/chezmoi/chezmoi.toml" --source "$SOURCE_ROOT" <"$SOURCE_ROOT/.chezmoiscripts/run_onchange_after_10_sync-skimi.sh.tmpl" >"$RENDERED_V1"
printf '%s\n' 'local skill v2' >"$SOURCE_ROOT/private_dot_config/skimi/skills/local-skill/SKILL.md"
chezmoi execute-template --config "$HOME/.config/chezmoi/chezmoi.toml" --source "$SOURCE_ROOT" <"$SOURCE_ROOT/.chezmoiscripts/run_onchange_after_10_sync-skimi.sh.tmpl" >"$RENDERED_V2"

if cmp -s "$RENDERED_V1" "$RENDERED_V2"; then
    echo "expected local skill changes to update skimi sync script fingerprint" >&2
    exit 1
fi

printf '%s\n' 'local skill' >"$SOURCE_ROOT/private_dot_config/skimi/skills/local-skill/SKILL.md"
mkdir -p "$HOME/.config/skimi/skills/skill_stale" "$HOME/.config/skimi/ai-now/legacy"
printf '%s\n' 'stale' >"$HOME/.config/skimi/skills/skill_stale/SKILL.md"
printf '%s\n' 'legacy' >"$HOME/.config/skimi/ai-now/legacy/SKILL.md"

RENDERED="$TMP_ROOT/skimi-sync.sh"
chezmoi execute-template --config "$HOME/.config/chezmoi/chezmoi.toml" --source "$SOURCE_ROOT" <"$SOURCE_ROOT/.chezmoiscripts/run_onchange_after_10_sync-skimi.sh.tmpl" >"$RENDERED"
chmod +x "$RENDERED"

BIN="$TMP_ROOT/bin"
mkdir -p "$BIN"
LOG="$TMP_ROOT/skimi.log"

cat >"$BIN/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "mise $*" >>"${SKIMI_TEST_LOG:?}"

case "${1:-}" in
activate)
    printf 'export PATH="%s"\n' "$PATH"
    ;;
*)
    echo "unexpected mise args: $*" >&2
    exit 2
    ;;
esac
EOF

cat >"$BIN/skimi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "skimi $*" >>"${SKIMI_TEST_LOG:?}"
EOF

chmod +x "$BIN/mise" "$BIN/skimi"

export SKIMI_TEST_LOG="$LOG"
export PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin"

bash "$RENDERED" >/dev/null 2>&1

[[ -f "$HOME/.config/skimi/skills/local-skill/SKILL.md" ]] || {
    echo "expected local skimi skills to be synced" >&2
    exit 1
}

[[ ! -e "$HOME/.config/skimi/skills/skill_stale" ]] || {
    echo "expected stale local skill to be deleted" >&2
    exit 1
}

[[ -f "$HOME/.config/skimi/ai-now/legacy/SKILL.md" ]] || {
    echo "expected legacy ai-now directory to remain untouched" >&2
    exit 1
}

grep -qxF 'mise activate bash' "$LOG" || {
    echo "expected mise activation" >&2
    cat "$LOG" >&2
    exit 1
}

grep -qxF 'skimi install' "$LOG" || {
    echo "expected skimi install" >&2
    cat "$LOG" >&2
    exit 1
}

echo "test_skimi_sync: OK"
