#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

expect_source_path() {
    local target="$1"
    local expected="$2"
    local got
    got="$(chezmoi source-path --source "$ROOT" "$target")"
    if [[ "$got" != "$expected" ]]; then
        echo "unexpected source path:" >&2
        echo "  target:    $target" >&2
        echo "  expected:  $expected" >&2
        echo "  got:       $got" >&2
        exit 1
    fi
}

expect_source_path "$HOME/.config/zellij/config.kdl" \
    "$ROOT/private_dot_config/zellij/config.kdl"
expect_source_path "$HOME/.config/zellij/plugins/zjstatus.wasm" \
    "$ROOT/private_dot_config/zellij/plugins/zjstatus.wasm"
expect_source_path "$HOME/.config/zellij/plugins/zjstatus-hints.wasm" \
    "$ROOT/private_dot_config/zellij/plugins/zjstatus-hints.wasm"
expect_source_path "$HOME/.config/zellij/plugins/zellij-palette.wasm" \
    "$ROOT/private_dot_config/zellij/plugins/zellij-palette.wasm"

config_file="$ROOT/private_dot_config/zellij/config.kdl"
rg -q 'shared \{' "$config_file"
rg -q 'bind "Ctrl Shift p"' "$config_file"
rg -q 'LaunchOrFocusPlugin "zellij-palette"' "$config_file"
rg -q 'bind "Alt t"' "$config_file"
rg -q 'bind "Alt o"' "$config_file"
rg -q 'plugins \{' "$config_file"
rg -q 'file:~/.config/zellij/plugins/zellij-palette\.wasm' "$config_file"

echo "test_zellij_config: OK"
