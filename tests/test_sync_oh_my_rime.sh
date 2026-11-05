#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPL="$ROOT/.chezmoiscripts/run_onchange_after_12_sync-oh-my-rime.sh.tmpl"
CUSTOM_TMPL="$ROOT/.chezmoitemplates/rime/squirrel.custom.yaml"
EXPECTED_COMMIT="cb4f7dda2fb74332cda0a7712ffc89ea5ded856f"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

command -v tar >/dev/null 2>&1 || {
    echo "SKIP: tar not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/oh-my-rime-sync-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
unset XDG_CACHE_HOME || true

mkdir -p "$HOME/.config/chezmoi"
cat >"$HOME/.config/chezmoi/chezmoi.toml" <<'EOF'
[data]
headless = false
EOF

SOURCE_ROOT="$TMP_ROOT/source"
mkdir -p \
    "$SOURCE_ROOT/.chezmoiscripts" \
    "$SOURCE_ROOT/.chezmoitemplates/shell"
cp "$TMPL" "$SOURCE_ROOT/.chezmoiscripts/run_onchange_after_12_sync-oh-my-rime.sh.tmpl"
cp "$ROOT/.chezmoitemplates/shell/source_nix_env.sh" "$SOURCE_ROOT/.chezmoitemplates/shell/source_nix_env.sh"
cp "$ROOT/.chezmoitemplates/shell/rime_deploy.sh" "$SOURCE_ROOT/.chezmoitemplates/shell/rime_deploy.sh"

RENDERED="$TMP_ROOT/sync-oh-my-rime.sh"
chezmoi execute-template \
    --config "$HOME/.config/chezmoi/chezmoi.toml" \
    --source "$SOURCE_ROOT" \
    --override-data '{"headless":false}' \
    <"$SOURCE_ROOT/.chezmoiscripts/run_onchange_after_12_sync-oh-my-rime.sh.tmpl" \
    >"$RENDERED"
chmod +x "$RENDERED"

grep -q "OH_MY_RIME_COMMIT=\"${EXPECTED_COMMIT}\"" "$RENDERED" || {
    echo "expected oh-my-rime pin ${EXPECTED_COMMIT}" >&2
    grep -E 'OH_MY_RIME_COMMIT=' "$RENDERED" >&2 || true
    exit 1
}

grep -q 'style/color_scheme: native' "$CUSTOM_TMPL" || {
    echo "expected squirrel.custom.yaml to keep native color scheme" >&2
    exit 1
}

FAKE_REPO="$TMP_ROOT/oh-my-rime-${EXPECTED_COMMIT}"
mkdir -p "$FAKE_REPO/dicts" "$FAKE_REPO/lua" "$FAKE_REPO/opencc"
printf '%s\n' 'squirrel: true' >"$FAKE_REPO/squirrel.yaml"
printf '%s\n' 'ibus: true' >"$FAKE_REPO/ibus_rime.yaml"
printf '%s\n' 'weasel: true' >"$FAKE_REPO/weasel.yaml"
printf '%s\n' 'default: true' >"$FAKE_REPO/default.yaml"
printf '%s\n' 'lua: true' >"$FAKE_REPO/rime.lua"
printf '%s\n' 'schema: true' >"$FAKE_REPO/rime_mint.schema.yaml"
printf '%s\n' 'dict: true' >"$FAKE_REPO/dicts/rime_mint.base.dict.yaml"
printf '%s\n' 'kp: true' >"$FAKE_REPO/lua/kp_number_processor.lua"
printf '%s\n' '{}' >"$FAKE_REPO/opencc/emoji.json"

ARCHIVE="$TMP_ROOT/oh-my-rime.tar.gz"
tar -czf "$ARCHIVE" -C "$TMP_ROOT" "$(basename "$FAKE_REPO")"
printf '%s\n' 'fake-gram' >"$TMP_ROOT/wanxiang.gram"

BIN="$TMP_ROOT/bin"
mkdir -p "$BIN"
LOG="$TMP_ROOT/sync.log"

cat >"$BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=""
url=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    -o)
        output="${2:?}"
        shift 2
        ;;
    --retry)
        shift 2
        ;;
    -*)
        shift
        ;;
    *)
        url="$1"
        shift
        ;;
    esac
done

[[ -n "$output" && -n "$url" ]] || {
    echo "curl stub missing -o or url: output=${output:-} url=${url:-}" >&2
    exit 2
}

echo "curl ${url}" >>"${OH_MY_RIME_TEST_LOG:?}"

case "$url" in
*oh-my-rime*)
    cp "${OH_MY_RIME_TEST_ARCHIVE:?}" "$output"
    ;;
*.gram)
    cp "${OH_MY_RIME_TEST_GRAM:?}" "$output"
    ;;
*)
    echo "unexpected curl url: $url" >&2
    exit 2
    ;;
esac
EOF

cat >"$BIN/Squirrel" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "squirrel $*" >>"${OH_MY_RIME_TEST_LOG:?}"
EOF

chmod +x "$BIN/curl" "$BIN/Squirrel"

TARGET_DIR="$HOME/Library/Rime"
mkdir -p "$TARGET_DIR"
printf '%s\n' 'keep-custom' >"$TARGET_DIR/squirrel.custom.yaml"
printf '%s\n' 'stale-managed' >"$TARGET_DIR/stale_upstream.yaml"
mkdir -p "$XDG_STATE_HOME/oh-my-rime"
printf '%s\n' 'oldcommit' >"$XDG_STATE_HOME/oh-my-rime/installed_commit"
printf '%s\n' 'stale_upstream.yaml' >"$XDG_STATE_HOME/oh-my-rime/upstream-managed-files.txt"

export OH_MY_RIME_TEST_LOG="$LOG"
export OH_MY_RIME_TEST_ARCHIVE="$ARCHIVE"
export OH_MY_RIME_TEST_GRAM="$TMP_ROOT/wanxiang.gram"
export OH_MY_RIME_PATH_PREFIX="$BIN"
export SQUIRREL_BIN="$BIN/Squirrel"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

bash "$RENDERED"

[[ -f "$TARGET_DIR/squirrel.yaml" ]] || {
    echo "expected darwin sync to copy squirrel.yaml" >&2
    ls -la "$TARGET_DIR" >&2
    exit 1
}

[[ ! -e "$TARGET_DIR/ibus_rime.yaml" ]] || {
    echo "did not expect ibus_rime.yaml on darwin" >&2
    exit 1
}

[[ ! -e "$TARGET_DIR/weasel.yaml" ]] || {
    echo "did not expect weasel.yaml on darwin" >&2
    exit 1
}

[[ -f "$TARGET_DIR/default.yaml" ]] || {
    echo "expected default.yaml to be copied" >&2
    exit 1
}

[[ -f "$TARGET_DIR/dicts/rime_mint.base.dict.yaml" ]] || {
    echo "expected dicts to be copied" >&2
    exit 1
}

[[ -f "$TARGET_DIR/lua/kp_number_processor.lua" ]] || {
    echo "expected lua to be copied" >&2
    exit 1
}

[[ "$(cat "$TARGET_DIR/squirrel.custom.yaml")" == "keep-custom" ]] || {
    echo "expected existing squirrel.custom.yaml to be preserved" >&2
    exit 1
}

[[ ! -e "$TARGET_DIR/stale_upstream.yaml" ]] || {
    echo "expected stale upstream file to be pruned" >&2
    exit 1
}

[[ "$(cat "$TARGET_DIR/wanxiang-lts-zh-hans.gram")" == "fake-gram" ]] || {
    echo "expected grammar file to be downloaded via stub" >&2
    exit 1
}

[[ "$(cat "$XDG_STATE_HOME/oh-my-rime/installed_commit")" == "$EXPECTED_COMMIT" ]] || {
    echo "expected installed commit ${EXPECTED_COMMIT}" >&2
    cat "$XDG_STATE_HOME/oh-my-rime/installed_commit" >&2
    exit 1
}

grep -qxF 'squirrel.yaml' "$XDG_STATE_HOME/oh-my-rime/upstream-managed-files.txt" || {
    echo "expected squirrel.yaml in upstream manifest" >&2
    cat "$XDG_STATE_HOME/oh-my-rime/upstream-managed-files.txt" >&2
    exit 1
}

if grep -qxF 'weasel.yaml' "$XDG_STATE_HOME/oh-my-rime/upstream-managed-files.txt"; then
    echo "did not expect weasel.yaml in upstream manifest" >&2
    exit 1
fi

grep -qxF 'squirrel --reload' "$LOG" || {
    echo "expected Squirrel --reload" >&2
    cat "$LOG" >&2
    exit 1
}

ARTIFACT="$TMP_ROOT/artifact.txt"
{
    echo "commit=$EXPECTED_COMMIT"
    echo "squirrel_yaml=yes"
    echo "weasel_yaml=no"
    echo "ibus_rime_yaml=no"
} >"$ARTIFACT"
[[ -s "$ARTIFACT" ]] || {
    echo "expected test artifact" >&2
    exit 1
}

echo "test_sync_oh_my_rime: OK"
