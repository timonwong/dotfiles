#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPL="$ROOT/nix-config/modules/apps.nix.tmpl"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/homebrew-activation-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$TMP_ROOT/config"
CONFIG="$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
mkdir -p "$HOME" "$(dirname "$CONFIG")"

cat >"$CONFIG" <<'EOF'
[data]
platform = "darwin"
work = false
private = false
installMasApps = false
timezone = "UTC"
EOF

rendered="$(chezmoi execute-template --config "$CONFIG" --source "$ROOT" <"$TMPL")"

printf '%s\n' "$rendered" | grep -q 'autoUpdate = false;' || {
    echo "expected homebrew.onActivation.autoUpdate = false" >&2
    printf '%s\n' "$rendered" >&2
    exit 1
}

printf '%s\n' "$rendered" | grep -q 'upgrade = false;' || {
    echo "expected homebrew.onActivation.upgrade = false" >&2
    printf '%s\n' "$rendered" >&2
    exit 1
}

printf '%s\n' "$rendered" | grep -q 'HOMEBREW_NO_INSTALL_UPGRADE = "1";' || {
    echo "expected Homebrew installs to preserve existing package versions" >&2
    printf '%s\n' "$rendered" >&2
    exit 1
}

if printf '%s\n' "$rendered" | grep -q 'HOMEBREW_NO_INSTALL_FROM_API'; then
    echo "expected Homebrew activation to use API metadata" >&2
    printf '%s\n' "$rendered" >&2
    exit 1
fi

echo "test_homebrew_activation: OK"
