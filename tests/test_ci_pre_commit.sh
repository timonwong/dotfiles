#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

workflow = (Path(sys.argv[1]) / ".github/workflows/ci.yml").read_text()
installs = re.findall(r"^\s*nix profile install (.+)$", workflow, re.M)
if not installs:
    raise SystemExit("ci.yml has no nix profile install command to check")
pre_commit_installs = [
    line
    for line in installs
    if any(pkg == "nixpkgs#pre-commit" for pkg in line.split())
]
if pre_commit_installs:
    raise SystemExit(
        "ci.yml must not install nixpkgs#pre-commit. That package hardcodes "
        "weekly's virtualenv, which crashes without packaging and shadows "
        f"pre-commit/action: {pre_commit_installs!r}"
    )

if "pre-commit/action@" not in workflow:
    raise SystemExit("ci.yml must run hooks with pre-commit/action")
PY

echo "test_ci_pre_commit: OK"
