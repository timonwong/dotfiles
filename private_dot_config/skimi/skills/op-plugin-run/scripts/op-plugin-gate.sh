#!/usr/bin/env bash
set -euo pipefail

SESSION_NAME="op-auth"
PLUGINS_FILE="${HOME}/.config/op/plugins.sh"

usage() {
    cat <<'USAGE'
Usage:
  op-plugin-gate.sh -- <command> [args...]

Behavior:
  - If ~/.config/op/plugins.sh exists, source it.
  - If tmux is unavailable, run command directly:
      op plugin run -- <command> [args...]
  - If tmux is available, run command in tmux session "op-auth".
  - If tmux session/window setup fails, fallback to direct execution.
USAGE
}

if [[ $# -lt 2 || "$1" != "--" ]]; then
    usage >&2
    exit 64
fi

shift
if [[ $# -lt 1 ]]; then
    usage >&2
    exit 64
fi

if [[ -f "$PLUGINS_FILE" ]]; then
    # shellcheck disable=SC1090
    if ! source "$PLUGINS_FILE"; then
        echo "[op-plugin-gate] warning: failed to source $PLUGINS_FILE; continuing" >&2
    fi
fi

cmd=(op plugin run -- "$@")

run_direct() {
    "${cmd[@]}"
}

if ! command -v tmux >/dev/null 2>&1; then
    run_direct
    exit $?
fi

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    if ! tmux new-session -d -s "$SESSION_NAME" >/dev/null 2>&1; then
        echo "[op-plugin-gate] warning: failed to create tmux session $SESSION_NAME; using direct fallback" >&2
        run_direct
        exit $?
    fi
fi

printf -v cmd_str '%q ' "${cmd[@]}"
cmd_str="${cmd_str% }"

if ! tmux new-window -d -t "$SESSION_NAME" "$cmd_str" >/dev/null 2>&1; then
    echo "[op-plugin-gate] warning: failed to create tmux window in $SESSION_NAME; using direct fallback" >&2
    run_direct
    exit $?
fi

if [[ -n "${TMUX:-}" ]]; then
    if ! tmux switch-client -t "$SESSION_NAME"; then
        echo "[op-plugin-gate] error: command already started in $SESSION_NAME, but switch-client failed; not running fallback" >&2
        exit 1
    fi
else
    if ! tmux attach -t "$SESSION_NAME"; then
        echo "[op-plugin-gate] error: command already started in $SESSION_NAME, but attach failed; not running fallback" >&2
        exit 1
    fi
fi
