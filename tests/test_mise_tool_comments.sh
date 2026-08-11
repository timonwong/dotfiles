#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])


def require_tool_comments(relative_path: str, famous_tools: set[str]) -> None:
    lines = (root / relative_path).read_text().splitlines()
    in_tools = False

    for index, line in enumerate(lines):
        stripped = line.strip()

        if stripped == "[tools]":
            in_tools = True
            continue
        if in_tools and stripped.startswith("["):
            break
        if not in_tools or not stripped or stripped.startswith(("#", "{{")):
            continue
        if "=" not in stripped:
            continue

        key = stripped.split("=", 1)[0].strip().strip('"')
        if key in famous_tools or key.startswith("github:timonwong/"):
            continue

        previous = index - 1
        while previous >= 0 and not lines[previous].strip():
            previous -= 1
        if previous < 0 or not lines[previous].lstrip().startswith("#"):
            raise SystemExit(f"missing purpose comment before {key} in {relative_path}")


require_tool_comments(
    "private_dot_config/mise/conf.d/managed-tools.toml",
    {
        "aqua:neovim/neovim",
        "aqua:openai/codex",
        "apko",
        "bat",
        "bun",
        "claude-code",
        "direnv",
        "fzf",
        "gh",
        "git-lfs",
        "go",
        "github:aria2/aria2",
        "jq",
        "kubectl",
        "rclone",
        "rg",
        "starship",
        "tmux",
        "yq",
    },
)

require_tool_comments(
    "private_dot_config/mise/config.toml.tmpl",
    {
        "helm",
        "node",
        "python",
        "yarn",
    },
)
PY

echo "test_mise_tool_comments: OK"
