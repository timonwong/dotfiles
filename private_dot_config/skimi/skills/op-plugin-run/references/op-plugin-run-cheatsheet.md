# op plugin run cheatsheet

Use these patterns for commands identified as managed by `plugins.sh`.

## Canonical routing

```bash
op plugin run -- <command> <args...>
```

## Common examples

```bash
op plugin run -- gh auth status
op plugin run -- gh pr checks 123
op plugin run -- glab auth status
op plugin run -- glab mr list
```

## With tmux session bootstrap

```bash
tmux new-session -Ad -s op-auth
tmux attach -t op-auth
op plugin run -- gh auth status
```

## Quick verification checklist

1. Command appears in parsed `managed_commands`.
2. Final command contains `op plugin run --`.
3. Command runs inside tmux (`existing` or `op-auth`).
4. No bare-command fallback is provided for managed commands.
