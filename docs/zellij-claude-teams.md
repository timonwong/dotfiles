# zellij-claude-teams

This repo vendors the runtime files from [`stanislc/zellij-claude-teams`](https://github.com/stanislc/zellij-claude-teams) into `chezmoi` so deployment stays under source control.

## Upstream Snapshot

- Repo: `https://github.com/stanislc/zellij-claude-teams`
- Commit: `020f2a5ce7c38d888fc94cf18472aa816815e120`
- Upstream date: `2026-04-19`
- Local compatibility patch: Claude Code v2.1.190+ `cat` placeholder and `respawn-pane` flow (see GitHub issue #4)

## Managed Targets

`chezmoi` manages these targets directly:

- `~/.local/share/zellij-tmux-shim/LICENSE`
- `~/.local/share/zellij-tmux-shim/activate.sh`
- `~/.local/share/zellij-tmux-shim/deactivate.sh`
- `~/.local/share/zellij-tmux-shim/bin/tmux`
- `~/.local/share/zellij-tmux-shim/bin/zellij-pane-wrapper`

`dot_zshrc` sources `activate.sh` whenever `$ZELLIJ` is set.

## Update Workflow

1. Fetch the latest upstream repo into a temporary directory.
2. Compare `activate.sh`, `deactivate.sh`, `bin/tmux`, `bin/zellij-pane-wrapper`, and `LICENSE`.
3. Copy the upstream content into:
   - `dot_local/share/zellij-tmux-shim/`
   - `dot_local/share/zellij-tmux-shim/bin/`
4. Update the vendored commit hash in this document and the file headers.
5. Run `bash tests/test_zellij_tmux_shim.sh`.

## Runtime Notes

- Run `claude` once in each working directory and accept workspace trust before creating agent teams.
- The shim activates only inside Zellij because `dot_zshrc` gates it on `$ZELLIJ`.
- Vendored Zellij wasm plugins live under `private_dot_config/zellij/plugins/` and are applied to
  `~/.config/zellij/plugins/`.
- `zellij-palette` should always be loaded from `~/.config/zellij/plugins/zellij-palette.wasm`.
  Update it by rebuilding in the `zellij-palette` repo and copying the new wasm into
  `private_dot_config/zellij/plugins/zellij-palette.wasm`.
