# Commit And PR Rules

- `git commit` messages must use Conventional Commits.
- Pull request titles must use Conventional Commits.
- Local validation for `chezmoi` must use an isolated config directory such as a temporary `XDG_CONFIG_HOME`.
- Keep `~/.config/chezmoi/chezmoi.toml` and other user-owned local config files unchanged during tests, renders, and bootstrap verification.
- Test fixtures for `chezmoi` config belong in temporary files or temporary config roots.

Examples:

- `feat: add zellij tmux shim support`
- `fix: align skipNix bootstrap entrypoints`
- `docs: update bootstrap instructions`
