#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skip-nix-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
mkdir -p "$HOME/.config/chezmoi"
unset XDG_CONFIG_HOME || true
CONFIG="$HOME/.config/chezmoi/chezmoi.toml"

cat >"$CONFIG" <<'EOF'
[data]
hostname = "skip-nix-host"
skipNix = true
EOF

STUB="$TMP_ROOT/stub"
mkdir -p "$STUB"
LOG="$TMP_ROOT/command.log"
export SKIP_NIX_TEST_LOG="$LOG"
SAFE_PATH="/bin:/usr/sbin:/sbin"

make_stub() {
    local name="$1"
    cat >"$STUB/$name" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "${0##*/} $*" >>"${SKIP_NIX_TEST_LOG:?}"
exit 99
EOF
    chmod +x "$STUB/$name"
}

for cmd in sudo nix darwin-rebuild mise skimi nix-locate curl wget uname sysctl head od grep awk mktemp chmod rm; do
    make_stub "$cmd"
done

render_script() {
    local template_path="$1"
    local output_path="$2"
    chezmoi execute-template --config "$CONFIG" --source "$ROOT" <"$template_path" >"$output_path"
    chmod +x "$output_path"
}

assert_skipped() {
    local runner="$1"
    local script="$2"

    : >"$LOG"
    set +e
    output="$(PATH="$STUB:$SAFE_PATH" "$runner" "$script" 2>&1)"
    rc=$?
    set -e

    if [[ $rc -ne 0 ]]; then
        echo "expected $script to exit 0, got $rc" >&2
        printf '%s\n' "$output" >&2
        exit 1
    fi

    if [[ "$output" != *"skipNix=true"* ]]; then
        echo "expected skipNix output from $script" >&2
        printf '%s\n' "$output" >&2
        exit 1
    fi

    if [[ -s "$LOG" ]]; then
        echo "expected no stubbed commands for $script" >&2
        cat "$LOG" >&2
        exit 1
    fi
}

render_script "$ROOT/.chezmoiscripts/run_onchange_before_00_install-nix.sh.tmpl" "$TMP_ROOT/install-nix.sh"
render_script "$ROOT/.chezmoiscripts/run_onchange_after_02_init.sh.tmpl" "$TMP_ROOT/init.sh"
render_script "$ROOT/.chezmoiscripts/run_onchange_after_03_set_profiles.sh.tmpl" "$TMP_ROOT/set-profiles.sh"
render_script "$ROOT/.chezmoiscripts/run_onchange_after_08_nix-index-db.sh.tmpl" "$TMP_ROOT/nix-index-db.sh"

assert_skipped sh "$TMP_ROOT/install-nix.sh"
assert_skipped bash "$TMP_ROOT/init.sh"
assert_skipped bash "$TMP_ROOT/set-profiles.sh"
assert_skipped bash "$TMP_ROOT/nix-index-db.sh"

: >"$LOG"
set +e
wrapper_output="$(PATH="$STUB:$SAFE_PATH" "$ROOT/.chezmoitemplates/shell/age_command_wrapper.sh" --version 2>&1)"
wrapper_rc=$?
set -e

if [[ $wrapper_rc -eq 0 ]]; then
    echo "expected age wrapper to fail when skipNix=true and age is absent" >&2
    exit 1
fi

if [[ "$wrapper_output" != *"skipNix=true"* ]]; then
    echo "expected age wrapper skipNix error" >&2
    printf '%s\n' "$wrapper_output" >&2
    exit 1
fi

if [[ -s "$LOG" ]]; then
    echo "expected age wrapper to avoid stubbed commands" >&2
    cat "$LOG" >&2
    exit 1
fi

echo "test_skip_nix: OK"
