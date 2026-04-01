# Script workflow

Wrapper entrypoint:

```bash
scripts/op-plugin-gate.sh -- <command> [args...]
```

Behavior summary:

1. If `~/.config/op/plugins.sh` exists, source it.
2. Build command as `op plugin run -- <command> [args...]`.
3. If tmux unavailable, run direct fallback in current shell.
4. If tmux available:
   - ensure session `op-auth`
   - run command in a new window in `op-auth`
   - attach/switch to `op-auth`
5. If tmux session/window creation fails, fallback direct.
6. If command already started in tmux and attach/switch fails, exit non-zero and do not fallback again.

The wrapper prints normal command output directly.
