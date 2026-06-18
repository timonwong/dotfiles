#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/sync-ai-now-skills.sh"

command -v rsync >/dev/null 2>&1 || {
    echo "SKIP: rsync not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sync-ai-now-skills-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

SOURCE="$TMP_ROOT/ai-now/skills"
TARGET_SOURCE="$TMP_ROOT/chezmoi-source"
TARGET="$TARGET_SOURCE/private_dot_config/skimi/ai-now"

mkdir -p "$SOURCE/skill_alpha/evals" "$TARGET/skill_stale"
cat >"$SOURCE/skill_alpha/SKILL.md" <<'EOF'
---
name: alpha
description: test skill
---
EOF
printf '%s\n' '{"ok":true}' >"$SOURCE/skill_alpha/evals/benchmark.jsonl"
printf '%s\n' 'mac artifact' >"$SOURCE/.DS_Store"
printf '%s\n' 'stale' >"$TARGET/skill_stale/SKILL.md"

AI_NOW_SKILLS_DIR="$SOURCE" CHEZMOI_SOURCE_DIR="$TARGET_SOURCE" "$SCRIPT" >/dev/null

[[ -f "$TARGET/skill_alpha/SKILL.md" ]] || {
    echo "expected SKILL.md to be synced" >&2
    exit 1
}

[[ -f "$TARGET/skill_alpha/evals/benchmark.jsonl" ]] || {
    echo "expected package files to be synced" >&2
    exit 1
}

[[ ! -e "$TARGET/.DS_Store" ]] || {
    echo "expected .DS_Store to be excluded" >&2
    exit 1
}

[[ ! -e "$TARGET/skill_stale" ]] || {
    echo "expected stale skill directory to be deleted" >&2
    exit 1
}

echo "test_sync_ai_now_skills: OK"
