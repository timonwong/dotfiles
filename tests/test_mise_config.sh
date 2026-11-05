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

chezmoi execute-template \
    --config "$CONFIG" \
    --source "$SOURCE_ROOT" \
    --override-data '{"platform":"darwin"}' \
    <"$TEMPLATE" >"$ARTIFACT"

if grep -nE '^[[:space:]]*always_keep_download[[:space:]]*=' "$TEMPLATE" "$ARTIFACT"; then
    echo "mise config must not set deprecated always_keep_download; finished downloads use download_cache" >&2
    exit 1
fi

echo "test_mise_config: OK ($ARTIFACT)"
