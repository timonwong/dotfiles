#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

out="$(chezmoi ignored --source "$ROOT" --override-data '{"useEncryption":false,"headless":false}')"

require_line() {
    local expected="$1"
    if ! printf '%s\n' "$out" | grep -qxF "$expected"; then
        echo "expected ignored entry not found: $expected" >&2
        echo "--- ignored output ---" >&2
        printf '%s\n' "$out" >&2
        exit 1
    fi
}

forbid_line() {
    local unexpected="$1"
    if printf '%s\n' "$out" | grep -qxF "$unexpected"; then
        echo "unexpected ignored entry found: $unexpected" >&2
        echo "--- ignored output ---" >&2
        printf '%s\n' "$out" >&2
        exit 1
    fi
}

# Always ignored (repo-only content).
require_line "docs"
require_line "tests"
forbid_line ".claude"

grep -qxF '.vscode/' "$ROOT/.chezmoiignore" || {
    echo "expected .vscode to be excluded from chezmoi targets" >&2
    exit 1
}

# When encryption is disabled, key-related scripts and targets must be ignored.
require_line ".chezmoiscripts/01_setup-encryption-key.sh"
require_line ".chezmoiscripts/07c_setup-gopass.sh"
# ~/.ssh/config is a create_ target with managed config.d defaults, not encryption-gated.

case "$(uname -s)" in
Darwin)
    require_line ".config/ibus/rime"
    forbid_line "Library/Rime"
    ;;
Linux)
    require_line "Library/Rime"
    forbid_line ".config/ibus/rime"
    ;;
esac

echo "test_chezmoiignore: OK"
