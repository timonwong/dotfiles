# tmux execution policy

Managed commands from `plugins.sh` are tmux-first, with controlled fallback only for tmux unavailability or tmux bootstrap failure.
Status must come from `scripts/op-plugin-gate.sh` output, not manual reasoning.

## Execution status model

- `ready`: tmux bootstrap to `op-auth` succeeded and command executed in `op-auth`.
- `degraded`: tmux binary missing OR tmux bootstrap failed.
- `blocked`: reserved for upstream parse failures (not tmux failures).

## Decision rule for managed commands

1. Run `command -v tmux`.
2. If tmux exists, attempt bootstrap:
   - `tmux has-session -t op-auth` (reuse if exists)
   - `tmux new-session -d -s op-auth` (create only when missing)
   - execute `op plugin run -- ...` in `op-auth` via script
3. If bootstrap+execution succeeds, mark `ready`.
4. If tmux is missing OR bootstrap fails, mark `degraded`, keep `op plugin run --` routing in direct fallback, and report failure evidence.

## Session default

- Session name: `op-auth`.
- `ready` path must execute in `op-auth` (no alternate tmux session).

## Execution examples

Ready (executed in `op-auth`):

```bash
scripts/op-plugin-gate.sh -- gh auth status
```

Degraded (tmux unavailable/failure):

```bash
# script executes fallback path and reports degrade reason
scripts/op-plugin-gate.sh --simulate-tmux-missing -- gh auth status
```

## Guardrails

- Do not suggest bare `gh`/`glab` for managed commands.
- Do not split sign-in and command execution across different short-lived shells.
- Do not label output as `ready` without confirmed tmux context.
- Do not handcraft tmux status when script output exists.
- Do not execute managed command outside script after `ready/degraded` is returned.
- `degraded` must include explicit reason:
  - `tmux_missing`, or
  - `tmux_bootstrap_failed` (with error summary/exit code if available).
