# op plugin run cheatsheet

Use these patterns for commands identified as managed by `plugins.sh`.

## Mandatory gate step

```bash
scripts/op-plugin-gate.sh -- <command> [args...]
```

Use script JSON as the only source of truth before routing and execution.

## Canonical routing (managed commands)

```bash
op plugin run -- <command> <args...>
```

## Status quick map

- `ready`: command executed in `op-auth` tmux session.
- `degraded`: tmux missing/bootstrap failed, command executed in direct fallback with `op plugin run --`.
- `blocked`: parse failed; do not return executable command.

## Ready examples

```bash
# command is executed by script in op-auth
scripts/op-plugin-gate.sh -- gh auth status
```

## Degraded examples

```bash
# tmux missing or bootstrap failed (script executes fallback)
scripts/op-plugin-gate.sh --simulate-tmux-missing -- gh pr checks 123
scripts/op-plugin-gate.sh --simulate-bootstrap-fail -- glab mr list
```

## Blocked example

```text
execution_status: blocked
reason: plugins.sh parse failed (malformed alias)
routed_command: n/a
fix: rewrite alias to canonical form alias xxx="op plugin run -- xxx"
```

## Quick verification checklist

1. Command appears in parsed `managed_commands`.
2. Output includes `execution_status: ready | degraded | blocked`.
3. Managed routed command (if present) contains `op plugin run --`.
4. `ready` implies `tmux_mode=op-auth` and `run_mode=tmux_op-auth`.
5. `degraded` includes `degrade_reason` and tmux error summary.
6. Output includes `command_status` + `command_exit_code`.
7. No bare-command fallback is provided for managed commands.
