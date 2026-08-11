#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import tomllib

root = Path(sys.argv[1])

with (root / "private_dot_config/mise/conf.d/managed-tools.toml").open("rb") as handle:
    tools = tomllib.load(handle)["tools"]

expected = {
    "actionlint": "1.7.12",
    "aqua:atuinsh/atuin": "18.19.0",
    "aqua:eth-p/bat-extras": "2024.08.24",
    "delta": "0.19.2",
    "difftastic": "0.70.0",
    "fzf": "0.74.2",
    "golangci-lint": "2.12.2",
    "lua-language-server": "3.19.0",
    "aqua:neovim/neovim": "0.12.4",
    "rclone": "1.75.0",
    "aqua:Kampfkarren/selene": "0.31.0",
    "shellcheck": "0.11.0",
    "starship": "1.26.0",
    "stylua": "2.5.2",
    "tree-sitter": "0.26.12",
    "aqua:numtide/treefmt": "2.5.0",
    "zoxide": "0.10.0",
}

for name, version in expected.items():
    actual = tools.get(name)
    if actual != version:
        raise SystemExit(f"expected {name}={version}, got {actual!r}")

if "shfmt" in tools:
    raise SystemExit("shfmt must remain Nix-managed and absent from mise tools")

retired_paths = [
    "private_dot_config/aquaproj-aqua/aqua.yaml",
    ".chezmoiscripts/run_onchange_after_04_setup-gopass.sh.tmpl",
    ".chezmoiscripts/run_onchange_after_05_install-aqua.sh.tmpl",
    ".chezmoiscripts/run_onchange_after_06_aqua-install-tools.sh.tmpl",
    ".chezmoiscripts/run_onchange_after_07c_generate-zellij-completion.sh.tmpl",
    ".github/workflows/update-toolchains.yml",
]
for relative in retired_paths:
    if (root / relative).exists():
        raise SystemExit(f"standalone Aqua path still exists: {relative}")

versions = (root / ".chezmoidata/versions.yaml").read_text()
for key in ("aquaInstaller", "aquaInstallerSha256", "aquaVersion"):
    if f"  {key}:" in versions:
        raise SystemExit(f"standalone Aqua version key still exists: {key}")

checks = {
    "dot_zshenv": ("AQUA_", "aquaproj-aqua"),
    "dot_local/bin/lib/common": ("ensure_aqua_environment", "command -v aqua"),
    ".github/workflows/scheduler.yml": ("update-toolchains",),
    ".github/workflows/update-versions.yml": ("aqua_installer", "aqua_version"),
}
for relative, needles in checks.items():
    content = (root / relative).read_text()
    for needle in needles:
        if needle in content:
            raise SystemExit(f"standalone Aqua reference {needle!r} remains in {relative}")

if not (root / ".chezmoiscripts/run_onchange_after_07c_setup-gopass.sh.tmpl").exists():
    raise SystemExit("gopass setup must run after mise installs managed tools")
if not (root / ".chezmoiscripts/run_onchange_after_07d_generate-zellij-completion.sh.tmpl").exists():
    raise SystemExit("zellij completion must follow the moved gopass setup step")

nix_packages = (root / ".chezmoidata/nix.yaml").read_text()
if "      - shfmt\n" not in nix_packages:
    raise SystemExit("shfmt must remain managed by the Nix package set")
PY

echo "test_mise_tool_migration: OK"
