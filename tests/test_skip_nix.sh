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

render_ignore() {
    local skip_nix_value="${1:-true}"
    local override_data
    override_data=$(printf '{"skipNix":%s,"headless":false,"useEncryption":true}' "$skip_nix_value")
    chezmoi execute-template --source "$ROOT" --override-data "$override_data" <"$ROOT/.chezmoiignore"
}

assert_ignored_with_skip_nix() {
    local rendered
    rendered="$(render_ignore)"

    local expected_paths=(
        ".chezmoiscripts/00_install-nix.sh"
        ".chezmoiscripts/02_init.sh"
        ".chezmoiscripts/03_set_profiles.sh"
        ".chezmoiscripts/08_nix-index-db.sh"
    )

    for path in "${expected_paths[@]}"; do
        if [[ "$rendered" != *"$path"* ]]; then
            echo "expected $path in .chezmoiignore when skipNix=true" >&2
            printf '%s\n' "$rendered" >&2
            exit 1
        fi
    done
}

assert_not_ignored_without_skip_nix() {
    local rendered
    rendered="$(render_ignore false)"

    if printf '%s\n' "$rendered" | grep -q '^\.chezmoiscripts/00_install-nix\.sh$'; then
        echo "did not expect 00_install-nix.sh in .chezmoiignore when skipNix=false" >&2
        exit 1
    fi
    if printf '%s\n' "$rendered" | grep -q '^\.chezmoiscripts/02_init\.sh$'; then
        echo "did not expect 02_init.sh in .chezmoiignore when skipNix=false" >&2
        exit 1
    fi
    if printf '%s\n' "$rendered" | grep -q '^\.chezmoiscripts/03_set_profiles\.sh$'; then
        echo "did not expect 03_set_profiles.sh in .chezmoiignore when skipNix=false" >&2
        exit 1
    fi
    if printf '%s\n' "$rendered" | grep -q '^\.chezmoiscripts/08_nix-index-db\.sh$'; then
        echo "did not expect 08_nix-index-db.sh in .chezmoiignore when skipNix=false" >&2
        exit 1
    fi
}

assert_ignored_with_skip_nix
assert_not_ignored_without_skip_nix

SAFE_PATH="/bin:/usr/sbin:/sbin"
set +e
wrapper_output="$(PATH="$SAFE_PATH" "$ROOT/.chezmoitemplates/shell/age_command_wrapper.sh" --version 2>&1)"
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

echo "test_skip_nix: OK"
