#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPL="$ROOT/nix-config/modules/profile.nix.tmpl"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/nix-profile-packages-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$TMP_ROOT/config"
SOURCE_ROOT="$TMP_ROOT/source"
CONFIG="$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
mkdir -p "$HOME" "$(dirname "$CONFIG")" "$SOURCE_ROOT/.chezmoidata" "$SOURCE_ROOT/nix-config/modules"
cp "$ROOT/.chezmoidata/nix.yaml" "$SOURCE_ROOT/.chezmoidata/nix.yaml"
cp "$TMPL" "$SOURCE_ROOT/nix-config/modules/profile.nix.tmpl"

cat >"$CONFIG" <<'EOF'
[data]
platform = "darwin"
work = false
private = false
EOF

rendered="$(chezmoi execute-template --config "$CONFIG" --source "$SOURCE_ROOT" <"$SOURCE_ROOT/nix-config/modules/profile.nix.tmpl")"

printf '%s\n' "$rendered" | grep -qxF '    nodejs' || {
    echo "expected Nix user profile to include nodejs" >&2
    printf '%s\n' "$rendered" >&2
    exit 1
}

echo "test_nix_profile_packages: OK"
