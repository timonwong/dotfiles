# tmux execution policy

Managed commands from `plugins.sh` must run in tmux for stable plugin auth flow.

## Decision rule

1. If already in tmux (`$TMUX` present), continue in current session.
2. If not in tmux, attach/create session `op-auth` first.
3. Run managed command only after tmux context is confirmed.

## Session default

- Session name: `op-auth`.
- Reuse preferred over creating many short-lived sessions.

## Execution examples

Inside tmux:

```bash
op plugin run -- gh auth status
```

Outside tmux:

```bash
tmux new-session -Ad -s op-auth
tmux attach -t op-auth
# then run
op plugin run -- gh auth status
```

## Guardrails

- Do not suggest bare `gh`/`glab` for managed commands.
- Do not split sign-in and command execution across different short-lived shells.
- If tmux unavailable, stop and state the missing prerequisite.
