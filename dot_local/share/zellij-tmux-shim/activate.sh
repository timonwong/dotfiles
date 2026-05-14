#!/usr/bin/env bash
# Vendored from github.com/stanislc/zellij-claude-teams
# Upstream commit: 020f2a5ce7c38d888fc94cf18472aa816815e120
# Source this file to activate the zellij-tmux-shim.
# Usage: source activate.sh

# Guard: only activate inside zellij
if [ -z "$ZELLIJ" ]; then
    echo "zellij-tmux-shim: not inside zellij, skipping activation" >&2
    return 1 2>/dev/null || exit 1
fi

# Guard: don't double-activate; always re-ensure PATH priority.
# Child shells inherit ZELLIJ_TMUX_SHIM_ACTIVE but rebuild PATH from
# shell config, pushing the shim behind other entries.
if [ -n "${ZELLIJ_TMUX_SHIM_ACTIVE:-}" ]; then
    export PATH="${ZELLIJ_TMUX_SHIM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zellij-tmux-shim}/bin:${PATH}"
    return 0 2>/dev/null || exit 0
fi

ZELLIJ_TMUX_SHIM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zellij-tmux-shim"

# Runtime state goes in an ephemeral, per-user, per-session directory.
_runtime_base="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
_shim_root="${_runtime_base}/zellij-tmux-shim-$(id -u)"
ZELLIJ_TMUX_SHIM_STATE="${_shim_root}/${ZELLIJ_SESSION_NAME:-default}"
unset _runtime_base

# Save real tmux path before we shadow it
ZELLIJ_TMUX_SHIM_REAL_TMUX="$(command -v tmux 2>/dev/null || true)"
export ZELLIJ_TMUX_SHIM_REAL_TMUX

# Save original PATH for deactivation
ZELLIJ_TMUX_SHIM_ORIG_PATH="$PATH"
export ZELLIJ_TMUX_SHIM_ORIG_PATH

# Prepend shim bin to PATH so our tmux shadows the real one
export PATH="${ZELLIJ_TMUX_SHIM_DIR}/bin:${PATH}"

# Set fake tmux env vars so Claude Code thinks it's inside tmux
export TMUX="zellij-shim:/tmp/zellij-shim,$$,0"
export TMUX_PANE="%0"

export ZELLIJ_TMUX_SHIM_DIR
export ZELLIJ_TMUX_SHIM_STATE

# Initialize state directory.
if [ -L "$_shim_root" ]; then
    echo "zellij-tmux-shim: ERROR: state root is a symlink, refusing to activate" >&2
    unset _shim_root
    return 1 2>/dev/null || exit 1
fi
command mkdir -p "$_shim_root"
chmod 700 "$_shim_root"
_owner=$(stat -c '%u' "$_shim_root" 2>/dev/null || stat -f '%u' "$_shim_root" 2>/dev/null)
if [ "$_owner" != "$(id -u)" ]; then
    echo "zellij-tmux-shim: ERROR: state root not owned by current user" >&2
    unset _shim_root _owner
    return 1 2>/dev/null || exit 1
fi
unset _owner
command mkdir -p "$ZELLIJ_TMUX_SHIM_STATE"
unset _shim_root

# Initialize next_id counter (start at 1, %0 is reserved for the host pane)
if [ ! -f "$ZELLIJ_TMUX_SHIM_STATE/next_id" ]; then
    echo "1" >"$ZELLIJ_TMUX_SHIM_STATE/next_id"
fi

# Initialize sessions file
if [ ! -f "$ZELLIJ_TMUX_SHIM_STATE/sessions" ]; then
    touch "$ZELLIJ_TMUX_SHIM_STATE/sessions"
fi

# Sweep stale state from prior crashed sessions.
command find "$ZELLIJ_TMUX_SHIM_STATE" -maxdepth 1 -name '*.pid' 2>/dev/null | while IFS= read -r _pidfile; do
    _pid=$(cat "$_pidfile" 2>/dev/null)
    if [ -n "$_pid" ] && ! kill -0 "$_pid" 2>/dev/null; then
        _key="${_pidfile##*/}"
        _key="${_key%.pid}"
        rm -f "$ZELLIJ_TMUX_SHIM_STATE/${_key}.pid" \
            "$ZELLIJ_TMUX_SHIM_STATE/${_key}.zellij_id" \
            "$ZELLIJ_TMUX_SHIM_STATE/${_key}.fifo" \
            "$ZELLIJ_TMUX_SHIM_STATE/${_key}.ready" \
            "$ZELLIJ_TMUX_SHIM_STATE/${_key}.cmd" \
            "$ZELLIJ_TMUX_SHIM_STATE/${_key}.named" \
            "$ZELLIJ_TMUX_SHIM_STATE/${_key}.group"
    fi
done

# Clean up orphaned .zellij_id files (no matching .pid = dead pane)
command find "$ZELLIJ_TMUX_SHIM_STATE" -maxdepth 1 -name '*.zellij_id' 2>/dev/null | while IFS= read -r _idfile; do
    _key="${_idfile##*/}"
    _key="${_key%.zellij_id}"
    [ -f "$ZELLIJ_TMUX_SHIM_STATE/${_key}.pid" ] || rm -f "$_idfile"
done

# Remove stale env snapshot and lock from prior sessions
rm -f "$ZELLIJ_TMUX_SHIM_STATE/parent.env"
rm -rf "$ZELLIJ_TMUX_SHIM_STATE/next_id.lock"

export ZELLIJ_TMUX_SHIM_ACTIVE=1
