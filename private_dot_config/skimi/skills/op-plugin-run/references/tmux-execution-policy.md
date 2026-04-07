# tmux execution policy

Session policy for wrapper:

- Fixed session name: `op-auth`
- no TTY: do not use tmux
- tmux available with TTY: command starts in `op-auth` and wrapper attaches/switches there
- tmux unavailable: direct fallback

Failure policy:

- session/window creation fails: direct fallback
