#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

command -v zsh >/dev/null 2>&1 || {
    echo "SKIP: zsh not found" >&2
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

expect_source_path "$HOME/.local/share/zellij-tmux-shim/activate.sh" \
    "$ROOT/dot_local/share/zellij-tmux-shim/activate.sh"
expect_source_path "$HOME/.local/share/zellij-tmux-shim/deactivate.sh" \
    "$ROOT/dot_local/share/zellij-tmux-shim/deactivate.sh"
expect_source_path "$HOME/.local/share/zellij-tmux-shim/bin/tmux" \
    "$ROOT/dot_local/share/zellij-tmux-shim/bin/executable_tmux"
expect_source_path "$HOME/.local/share/zellij-tmux-shim/bin/zellij-pane-wrapper" \
    "$ROOT/dot_local/share/zellij-tmux-shim/bin/executable_zellij-pane-wrapper"
expect_source_path "$HOME/.custom/zellij.sh" \
    "$ROOT/dot_custom/zellij.sh.tmpl"

if ! rg -q 'source "\$HOME/\.custom/zellij\.sh"' "$ROOT/dot_zshrc"; then
    echo "dot_zshrc is missing zellij custom source" >&2
    exit 1
fi

if ! rg -q 'zellij-tmux-shim/activate\.sh' "$ROOT/dot_custom/zellij.sh.tmpl"; then
    echo "dot_zshrc is missing zellij-tmux-shim activation snippet" >&2
    exit 1
fi

if ! rg -q '^zj\(\)' "$ROOT/dot_custom/zellij.sh.tmpl"; then
    echo "dot_zshrc is missing zj helper" >&2
    exit 1
fi

if rg -q 'exec zellij attach' "$ROOT/dot_custom/zellij.sh.tmpl"; then
    echo "dot_zshrc still auto-attaches zellij" >&2
    exit 1
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/zellij-tmux-shim-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p \
    "$HOME/.local/share/zellij-tmux-shim/bin" \
    "$TMP_ROOT/bin" \
    "$TMP_ROOT/tmp"

cp "$ROOT/dot_local/share/zellij-tmux-shim/activate.sh" \
    "$HOME/.local/share/zellij-tmux-shim/activate.sh"
cp "$ROOT/dot_local/share/zellij-tmux-shim/deactivate.sh" \
    "$HOME/.local/share/zellij-tmux-shim/deactivate.sh"
cp "$ROOT/dot_local/share/zellij-tmux-shim/bin/executable_tmux" \
    "$HOME/.local/share/zellij-tmux-shim/bin/tmux"
cp "$ROOT/dot_local/share/zellij-tmux-shim/bin/executable_zellij-pane-wrapper" \
    "$HOME/.local/share/zellij-tmux-shim/bin/zellij-pane-wrapper"
chmod +x \
    "$HOME/.local/share/zellij-tmux-shim/bin/tmux" \
    "$HOME/.local/share/zellij-tmux-shim/bin/zellij-pane-wrapper"

cat >"$TMP_ROOT/bin/tmux" <<'EOF'
#!/usr/bin/env bash
echo "real tmux"
EOF
chmod +x "$TMP_ROOT/bin/tmux"

export TMPDIR="$TMP_ROOT/tmp"
export PATH="$TMP_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export ZELLIJ=shim-test
export ZELLIJ_SESSION_NAME=shim-session

zsh -fc '
source "$HOME/.local/share/zellij-tmux-shim/activate.sh"
[[ "${ZELLIJ_TMUX_SHIM_ACTIVE:-}" == "1" ]]
[[ "$(command -v tmux)" == "$HOME/.local/share/zellij-tmux-shim/bin/tmux" ]]
[[ "${ZELLIJ_TMUX_SHIM_REAL_TMUX:-}" == "'"$TMP_ROOT"'/bin/tmux" ]]
'

stdout_file="$TMP_ROOT/stdout"
zsh -ic '
alias mkdir="mkdir -pv"
source "$HOME/.local/share/zellij-tmux-shim/activate.sh"
' >"$stdout_file"

if [[ -s "$stdout_file" ]]; then
    echo "activate.sh produced unexpected stdout:" >&2
    cat "$stdout_file" >&2
    exit 1
fi

# Claude Code v2.1.190+ creates a pane with a `cat` placeholder and then
# respawns it with the real command. Verify the placeholder is not delivered
# and respawn-pane preserves shell operators such as `&&` verbatim.
RESPAWN_STATE="$TMP_ROOT/respawn-state"
mkdir -p "$RESPAWN_STATE"
mkfifo "$RESPAWN_STATE/3.fifo"
cat "$RESPAWN_STATE/3.fifo" >"$RESPAWN_STATE/3.received" &
FIFO_READER_PID=$!
touch "$RESPAWN_STATE/3.named"
export ZELLIJ_TMUX_SHIM_STATE="$RESPAWN_STATE"
export ZELLIJ_TMUX_SHIM_DIR="$HOME/.local/share/zellij-tmux-shim"
"$HOME/.local/share/zellij-tmux-shim/bin/tmux" respawn-pane -k -t %3 -- cd /tmp '&&' env FOO=bar claude --agent-name X
wait "$FIFO_READER_PID"
[[ "$(<"$RESPAWN_STATE/3.received")" == 'cd /tmp && env FOO=bar claude --agent-name X' ]]

echo "test_zellij_tmux_shim: OK"
