#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMPLATE="$ROOT/private_dot_config/mise/config.toml.tmpl"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mise-config-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
SOURCE_ROOT="$TMP_ROOT/source"
CONFIG="$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
ARTIFACT="$TMP_ROOT/rendered-mise-config.toml"

mkdir -p "$SOURCE_ROOT" "$(dirname "$CONFIG")"
cat >"$CONFIG" <<'EOF'
[data]
EOF

LINUX_ARTIFACT="$TMP_ROOT/rendered-mise-config-linux.toml"

chezmoi execute-template \
    --config "$CONFIG" \
    --source "$SOURCE_ROOT" \
    --override-data '{"platform":"darwin"}' \
    <"$TEMPLATE" >"$ARTIFACT"

chezmoi execute-template \
    --config "$CONFIG" \
    --source "$SOURCE_ROOT" \
    --override-data '{"platform":"linux"}' \
    <"$TEMPLATE" >"$LINUX_ARTIFACT"

if grep -nE '^[[:space:]]*always_keep_download[[:space:]]*=' "$TEMPLATE" "$ARTIFACT"; then
    echo "mise config must not set deprecated always_keep_download; finished downloads use download_cache" >&2
    exit 1
fi

if [[ -e "$ROOT/private_dot_config/mise/private_config.toml.tmpl" ]]; then
    echo "private_config.toml.tmpl conflicts with config.toml.tmpl for the same dest" >&2
    exit 1
fi

for rendered in "$ARTIFACT" "$LINUX_ARTIFACT"; do
    for wanted in \
        'wrappers = { cargo = { command = "mbx", env = { MBX_CARGO_SHIM_MODE = "1" } } }' \
        'rust = { version = "latest", mr_boxington = true }' \
        'mr-boxington = { version = "latest", workflow = "release.yml@refs/heads/main" }'; do
        grep -qxF "$wanted" "$rendered" || {
            echo "managed mise config must set '$wanted' on every platform: $rendered" >&2
            exit 1
        }
    done
    # wrappers is a top-level key, so it must come before the first table.
    if [[ "$(grep -nE '^(wrappers = |\[)' "$rendered" | head -1)" != *"wrappers = "* ]]; then
        echo "wrappers must be set before the first TOML table: $rendered" >&2
        exit 1
    fi
done

grep -q 'config.local.toml' "$TEMPLATE" || {
    echo "managed mise config must point machine-local overlays at config.local.toml" >&2
    exit 1
}

grep -qxF '.config/mise/config.local.toml' "$ROOT/.chezmoiignore" || {
    echo ".chezmoiignore must leave config.local.toml unmanaged" >&2
    exit 1
}

echo "test_mise_config: OK ($ARTIFACT)"
