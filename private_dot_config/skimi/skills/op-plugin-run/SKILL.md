---
name: op-plugin-run
description: Use when running plugin-managed CLIs (especially `gh` and `glab`) and route execution through `op plugin run` with `op-auth` tmux session enforcement plus direct fallback when tmux is unavailable.
metadata:
  skill-type: infrastructure_ops
---

# Op Plugin Run

Use a single wrapper script to run managed commands:

- Script candidates:
  - `scripts/op-plugin-gate.sh`
  - `~/.agents/skills/op-plugin-run/scripts/op-plugin-gate.sh`
- Session: `op-auth`
- Route: `op plugin run -- <command> [args...]`

## When to use

- User asks to run `gh` or `glab` through 1Password plugin auth.
- You want tmux-backed foreground execution in `op-auth` when tmux works.
- You want direct fallback if tmux is missing or tmux setup fails.
- You want non-interactive environments (no TTY) to skip tmux.

## Hard constraints

- Always enter through a resolved wrapper path and run `<wrapper> -- <command> [args...]`.
- Do not run managed command as bare `gh`/`glab`.
- If no executable wrapper is found, stop and report blocked. Do not fallback to bare `gh`/`glab`.

## Workflow

1. Resolve wrapper path in this order:
   - `scripts/op-plugin-gate.sh`
   - `~/.agents/skills/op-plugin-run/scripts/op-plugin-gate.sh`
2. For each candidate that exists, try `chmod +x <path>` before checking executable bit.
3. If no executable wrapper is found, stop and return a blocked error.
4. Run wrapper:
   - `<resolved-wrapper> -- <command> [args...]`
5. Wrapper behavior:
   - If `~/.config/op/plugins.sh` exists: `source` it.
   - If no TTY: run direct `op plugin run -- ...` (do not use tmux).
   - If tmux missing: run direct `op plugin run -- ...`.
   - If tmux available with TTY: ensure `op-auth`, run command in `op-auth` window, then attach/switch into `op-auth`.
   - If tmux session/window creation fails: direct fallback.
6. Use command output directly. Wrapper is transparent and does not emit structured JSON.

## Breaking changes

- Old status/JSON output removed.
- Old flags removed (`--timeout-sec`, `--simulate-*`, `--skip-exec`, etc.).
- Only supported interface:
  - `op-plugin-gate.sh -- <command> [args...]`

## Quick checks

- Resolve wrapper and check executable:
  - `for p in scripts/op-plugin-gate.sh ~/.agents/skills/op-plugin-run/scripts/op-plugin-gate.sh; do [ -f \"$p\" ] && chmod +x \"$p\" 2>/dev/null || true; [ -x \"$p\" ] && echo \"OP_GATE_OK $p\" && break; done`
- Usage guard:
  - `<resolved-wrapper>` should fail with usage when called without `-- <command>`.
- Normal path:
  - `<resolved-wrapper> -- gh auth status`

## References

- `references/script-workflow.md`
