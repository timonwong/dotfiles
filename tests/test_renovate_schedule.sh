#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import json
import sys

root = Path(sys.argv[1])
config = json.loads((root / ".github/renovate.json").read_text())

timezone = config.get("timezone")
if timezone != "Asia/Tokyo":
    raise SystemExit(f"expected timezone Asia/Tokyo, got {timezone!r}")

schedule = config.get("schedule")
if schedule != ["after 12am and before 7am"]:
    raise SystemExit(
        "expected renovate schedule after 12am and before 7am Asia/Tokyo, "
        f"got {schedule!r}"
    )

hourly = config.get("prHourlyLimit")
if hourly != 0:
    raise SystemExit(f"expected prHourlyLimit 0 to disable the hourly cap, got {hourly!r}")

concurrent = config.get("prConcurrentLimit")
if concurrent != 0:
    raise SystemExit(
        f"expected prConcurrentLimit 0 to disable the open-PR cap, got {concurrent!r}"
    )
PY

echo "test_renovate_schedule: OK"
