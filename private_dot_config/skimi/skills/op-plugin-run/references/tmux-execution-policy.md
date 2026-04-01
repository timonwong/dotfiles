# tmux execution policy

Session policy for wrapper:

- Fixed session name: `op-auth`
- tmux available: command starts in `op-auth`
- tmux unavailable: direct fallback

Failure policy:

- session/window creation fails: direct fallback
- command already started in tmux but attach/switch fails: do not fallback again
