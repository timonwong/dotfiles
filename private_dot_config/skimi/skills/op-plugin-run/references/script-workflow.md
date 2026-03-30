# script workflow

This skill is script-first. Never handcraft status decisions.
`op-plugin-gate.sh` is a bash wrapper with embedded `python3` logic for maintainability.

## Mandatory entrypoint

```bash
scripts/op-plugin-gate.sh -- <command> [args...]
```

The script output is authoritative for:

- `parse_status`
- `managed`
- `execution_status`
- `routed_command`
- tmux fallback reason fields
- command execution result fields

## Minimal run flow

1. Run gate script with target command.
2. Read JSON output.
3. Apply status strictly:
   - `ready`: command already executed in `op-auth`.
   - `degraded`: command already executed in direct fallback path.
   - `blocked`: stop and return `reason` + `fix`.
4. Do not execute the same managed command again outside script.

## Testing switches

- `--simulate-tmux-missing`: force degraded path (`tmux_missing`).
- `--simulate-bootstrap-fail`: force degraded path (`tmux_bootstrap_failed`).

## Example outputs

```bash
scripts/op-plugin-gate.sh -- gh auth status
scripts/op-plugin-gate.sh --simulate-tmux-missing -- gh pr checks 123
scripts/op-plugin-gate.sh --simulate-bootstrap-fail -- glab mr list
scripts/op-plugin-gate.sh --timeout-sec 30 -- gh pr checks 123
```
