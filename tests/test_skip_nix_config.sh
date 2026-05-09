#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skip-nix-config-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
mkdir -p "$HOME"
unset XDG_CONFIG_HOME || true

render_config() {
    chezmoi execute-template \
        --init \
        --source "$ROOT" \
        --stdinisatty=false \
        "$@" \
        <"$ROOT/.chezmoi.toml.tmpl"
}

default_rendered="$(render_config)"
printf '%s\n' "$default_rendered" | grep -q '^skipNix = false$' || {
    echo "expected default skipNix = false" >&2
    printf '%s\n' "$default_rendered" >&2
    exit 1
}

override_rendered="$(render_config --override-data '{"skipNix":true}')"
printf '%s\n' "$override_rendered" | grep -q '^skipNix = true$' || {
    echo "expected override skipNix = true" >&2
    printf '%s\n' "$override_rendered" >&2
    exit 1
}

echo "test_skip_nix_config: OK"
