---
name: op-plugin-run
description: Use when running plugin-managed CLIs (especially `gh` and `glab`) and route execution through `op plugin run` with `op-auth` tmux session enforcement plus direct fallback when tmux is unavailable.
metadata:
  skill-type: infrastructure_ops
---

# Op Plugin Run

Use a single wrapper script to run managed commands:

- Script: `scripts/op-plugin-gate.sh`
- Session: `op-auth`
- Route: `op plugin run -- <command> [args...]`

## When to use

- User asks to run `gh` or `glab` through 1Password plugin auth.
- You want tmux-backed execution in `op-auth` when tmux works.
- You want direct fallback if tmux is missing or tmux setup fails.

## Hard constraints

- Always enter through `scripts/op-plugin-gate.sh -- <command> [args...]`.
- Do not run managed command as bare `gh`/`glab`.
- If command already started in tmux and `attach/switch` fails, do not run fallback again.

## Workflow

1. Run wrapper:
   - `scripts/op-plugin-gate.sh -- <command> [args...]`
2. Wrapper behavior:
   - If `~/.config/op/plugins.sh` exists: `source` it.
   - If tmux missing: run direct `op plugin run -- ...`.
   - If tmux available: ensure `op-auth`, run command in `op-auth` window, then attach/switch to `op-auth`.
   - If tmux session/window creation fails: direct fallback.
3. Use command output directly. Wrapper is transparent and does not emit structured JSON.

## Breaking changes

- Old status/JSON output removed.
- Old flags removed (`--timeout-sec`, `--simulate-*`, `--skip-exec`, etc.).
- Only supported interface:
  - `op-plugin-gate.sh -- <command> [args...]`

## Quick checks

- Script executable:
  - `test -x scripts/op-plugin-gate.sh`
- Usage guard:
  - `scripts/op-plugin-gate.sh` should fail with usage.
- Normal path:
  - `scripts/op-plugin-gate.sh -- gh auth status`

## References

- `references/script-workflow.md`
