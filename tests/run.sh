#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

# Tests rewrite HOME to isolated temp dirs. Ensure chezmoi follows those per-test
# configs instead of any runner-provided global XDG config path.
unset XDG_CONFIG_HOME || true

echo "== Running bootstrap tests =="

python3 "$ROOT/tests/test_setup_encryption_key.py"
bash "$ROOT/tests/test_init_args.sh"
bash "$ROOT/tests/test_install_nix_arch.sh"
bash "$ROOT/tests/test_mise_installer.sh"
bash "$ROOT/tests/test_mise_install_fallback.sh"
bash "$ROOT/tests/test_mise_tool_migration.sh"
bash "$ROOT/tests/test_mise_tool_comments.sh"
bash "$ROOT/tests/test_sync_ai_now_skills.sh"
bash "$ROOT/tests/test_skimi_config_template.sh"
bash "$ROOT/tests/test_pi_config.sh"
bash "$ROOT/tests/test_skimi_sync.sh"
bash "$ROOT/tests/test_homebrew_activation.sh"
bash "$ROOT/tests/test_skip_nix_config.sh"
bash "$ROOT/tests/test_skip_nix.sh"
bash "$ROOT/tests/test_chezmoiignore.sh"
bash "$ROOT/tests/test_zellij_config.sh"
bash "$ROOT/tests/test_zellij_tmux_shim.sh"
bash "$ROOT/tests/test_setup_gopass.sh"
bash "$ROOT/tests/test_keys_manage_nonmenu.sh"

echo "OK"
