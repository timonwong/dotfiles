#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPL="$ROOT/.chezmoiscripts/run_onchange_after_12_sync-rime-wanxiang.sh.tmpl"
CUSTOM_TMPL="$ROOT/.chezmoitemplates/rime/squirrel.custom.yaml"
DEFAULT_CUSTOM="$ROOT/.chezmoitemplates/rime/default.custom.yaml"
WANXIANG_CUSTOM="$ROOT/.chezmoitemplates/rime/wanxiang.custom.yaml"
EXPECTED_VERSION="v18.1.9"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

command -v zip >/dev/null 2>&1 || {
    echo "SKIP: zip not found" >&2
    exit 0
}

command -v unzip >/dev/null 2>&1 || {
    echo "SKIP: unzip not found" >&2
    exit 0
}

[[ -f "$TMPL" ]] || {
    echo "expected ${TMPL}" >&2
    exit 1
}

[[ -f "$WANXIANG_CUSTOM" ]] || {
    echo "expected wanxiang.custom.yaml template" >&2
    exit 1
}

[[ ! -e "$ROOT/.chezmoitemplates/rime/rime_mint.custom.yaml" ]] || {
    echo "did not expect rime_mint.custom.yaml after switching to wanxiang" >&2
    exit 1
}

grep -q 'schema: wanxiang' "$DEFAULT_CUSTOM" || {
    echo "expected default.custom.yaml to enable wanxiang" >&2
    exit 1
}

if grep -q 'schema: rime_mint' "$DEFAULT_CUSTOM"; then
    echo "did not expect rime_mint in default.custom.yaml" >&2
    exit 1
fi

grep -q 'wanxiang_algebra:/base/全拼' "$WANXIANG_CUSTOM" || {
    echo "expected wanxiang.custom.yaml to keep full pinyin algebra" >&2
    exit 1
}

grep -q 'wanxiang_algebra:/模糊音_nl' "$WANXIANG_CUSTOM" || {
    echo "expected n/l fuzzy pinyin" >&2
    exit 1
}

grep -q '"switches/@3/reset": 1' "$WANXIANG_CUSTOM" || {
    echo "expected emoji switch default on" >&2
    exit 1
}

grep -q 'style/color_scheme: native' "$CUSTOM_TMPL" || {
    echo "expected squirrel.custom.yaml to keep native color scheme" >&2
    exit 1
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rime-wanxiang-sync-test.XXXXXX")"
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
cp "$TMPL" "$SOURCE_ROOT/.chezmoiscripts/run_onchange_after_12_sync-rime-wanxiang.sh.tmpl"
cp "$ROOT/.chezmoitemplates/shell/source_nix_env.sh" "$SOURCE_ROOT/.chezmoitemplates/shell/source_nix_env.sh"
cp "$ROOT/.chezmoitemplates/shell/rime_deploy.sh" "$SOURCE_ROOT/.chezmoitemplates/shell/rime_deploy.sh"

RENDERED="$TMP_ROOT/sync-rime-wanxiang.sh"
chezmoi execute-template \
    --config "$HOME/.config/chezmoi/chezmoi.toml" \
    --source "$SOURCE_ROOT" \
    --override-data '{"headless":false}' \
    <"$SOURCE_ROOT/.chezmoiscripts/run_onchange_after_12_sync-rime-wanxiang.sh.tmpl" \
    >"$RENDERED"
chmod +x "$RENDERED"

grep -q "WANXIANG_VERSION=\"${EXPECTED_VERSION}\"" "$RENDERED" || {
    echo "expected rime-wanxiang pin ${EXPECTED_VERSION}" >&2
    grep -E 'WANXIANG_VERSION=' "$RENDERED" >&2 || true
    exit 1
}

grep -q 'rime-wanxiang-base.zip' "$RENDERED" || {
    echo "expected Base zip download" >&2
    exit 1
}

FAKE_REPO="$TMP_ROOT/rime-wanxiang-base"
mkdir -p "$FAKE_REPO/dicts" "$FAKE_REPO/lua/wanxiang" "$FAKE_REPO/opencc" "$FAKE_REPO/docs"
printf '%s\n' 'squirrel: true' >"$FAKE_REPO/squirrel.yaml"
printf '%s\n' 'ibus: true' >"$FAKE_REPO/ibus_rime.yaml"
printf '%s\n' 'weasel: true' >"$FAKE_REPO/weasel.yaml"
printf '%s\n' 'default: true' >"$FAKE_REPO/default.yaml"
printf '%s\n' 'schema: true' >"$FAKE_REPO/wanxiang.schema.yaml"
printf '%s\n' 'dict: true' >"$FAKE_REPO/dicts/jichu.dict.yaml"
printf '%s\n' 'lua: true' >"$FAKE_REPO/lua/wanxiang/super_processor.lua"
printf '%s\n' '{}' >"$FAKE_REPO/opencc/emoji.json"
printf '%s\n' 'docs' >"$FAKE_REPO/docs/readme.md"
printf '%s\n' 'readme' >"$FAKE_REPO/README.md"

ARCHIVE="$TMP_ROOT/rime-wanxiang-base.zip"
(
    cd "$TMP_ROOT"
    zip -qr "$ARCHIVE" "$(basename "$FAKE_REPO")"
)
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

echo "curl ${url}" >>"${RIME_WANXIANG_TEST_LOG:?}"

case "$url" in
*rime-wanxiang-base.zip*)
    cp "${RIME_WANXIANG_TEST_ARCHIVE:?}" "$output"
    ;;
*.gram)
    cp "${RIME_WANXIANG_TEST_GRAM:?}" "$output"
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

echo "squirrel $*" >>"${RIME_WANXIANG_TEST_LOG:?}"
EOF

chmod +x "$BIN/curl" "$BIN/Squirrel"

TARGET_DIR="$HOME/Library/Rime"
mkdir -p "$TARGET_DIR"
printf '%s\n' 'keep-custom' >"$TARGET_DIR/squirrel.custom.yaml"
printf '%s\n' 'keep-userdb' >"$TARGET_DIR/rime_mint.userdb"
printf '%s\n' 'stale-managed' >"$TARGET_DIR/stale_upstream.yaml"
printf '%s\n' 'mint-schema' >"$TARGET_DIR/rime_mint.schema.yaml"
mkdir -p "$XDG_STATE_HOME/oh-my-rime"
printf '%s\n' 'oldcommit' >"$XDG_STATE_HOME/oh-my-rime/installed_commit"
printf '%s\n' 'stale_upstream.yaml' 'rime_mint.schema.yaml' >"$XDG_STATE_HOME/oh-my-rime/upstream-managed-files.txt"

export RIME_WANXIANG_TEST_LOG="$LOG"
export RIME_WANXIANG_TEST_ARCHIVE="$ARCHIVE"
export RIME_WANXIANG_TEST_GRAM="$TMP_ROOT/wanxiang.gram"
export RIME_WANXIANG_PATH_PREFIX="$BIN"
export SQUIRREL_BIN="$BIN/Squirrel"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

bash "$RENDERED"

[[ -f "$TARGET_DIR/squirrel.yaml" ]] || {
    echo "expected darwin sync to copy squirrel.yaml when present" >&2
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

[[ ! -e "$TARGET_DIR/README.md" ]] || {
    echo "did not expect upstream README.md" >&2
    exit 1
}

[[ ! -e "$TARGET_DIR/docs/readme.md" ]] || {
    echo "did not expect docs/ to be copied" >&2
    exit 1
}

[[ -f "$TARGET_DIR/default.yaml" ]] || {
    echo "expected default.yaml to be copied" >&2
    exit 1
}

[[ -f "$TARGET_DIR/wanxiang.schema.yaml" ]] || {
    echo "expected wanxiang.schema.yaml to be copied" >&2
    exit 1
}

[[ -f "$TARGET_DIR/dicts/jichu.dict.yaml" ]] || {
    echo "expected dicts to be copied" >&2
    exit 1
}

[[ -f "$TARGET_DIR/lua/wanxiang/super_processor.lua" ]] || {
    echo "expected lua to be copied" >&2
    exit 1
}

[[ "$(cat "$TARGET_DIR/squirrel.custom.yaml")" == "keep-custom" ]] || {
    echo "expected existing squirrel.custom.yaml to be preserved" >&2
    exit 1
}

[[ "$(cat "$TARGET_DIR/rime_mint.userdb")" == "keep-userdb" ]] || {
    echo "expected existing userdb file to be preserved" >&2
    exit 1
}

[[ ! -e "$TARGET_DIR/stale_upstream.yaml" ]] || {
    echo "expected stale oh-my-rime file to be pruned" >&2
    exit 1
}

[[ ! -e "$TARGET_DIR/rime_mint.schema.yaml" ]] || {
    echo "expected old rime_mint.schema.yaml to be pruned from previous manifest" >&2
    exit 1
}

[[ "$(cat "$TARGET_DIR/wanxiang-lts-zh-hans.gram")" == "fake-gram" ]] || {
    echo "expected grammar file to be downloaded via stub" >&2
    exit 1
}

[[ "$(cat "$XDG_STATE_HOME/rime-wanxiang/installed_version")" == "$EXPECTED_VERSION" ]] || {
    echo "expected installed version ${EXPECTED_VERSION}" >&2
    cat "$XDG_STATE_HOME/rime-wanxiang/installed_version" >&2
    exit 1
}

grep -qxF 'squirrel.yaml' "$XDG_STATE_HOME/rime-wanxiang/upstream-managed-files.txt" || {
    echo "expected squirrel.yaml in upstream manifest" >&2
    cat "$XDG_STATE_HOME/rime-wanxiang/upstream-managed-files.txt" >&2
    exit 1
}

if grep -qxF 'weasel.yaml' "$XDG_STATE_HOME/rime-wanxiang/upstream-managed-files.txt"; then
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
    echo "version=$EXPECTED_VERSION"
    echo "squirrel_yaml=yes"
    echo "weasel_yaml=no"
    echo "ibus_rime_yaml=no"
    echo "mint_schema_pruned=yes"
} >"$ARTIFACT"
[[ -s "$ARTIFACT" ]] || {
    echo "expected test artifact" >&2
    exit 1
}

echo "test_sync_rime_wanxiang: OK"
