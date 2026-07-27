#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/sync-ai-now-skills.sh"

command -v rsync >/dev/null 2>&1 || {
    echo "SKIP: rsync not found" >&2
    exit 0
}

command -v git >/dev/null 2>&1 || {
    echo "SKIP: git not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sync-ai-now-skills-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export GIT_CONFIG_GLOBAL="$TMP_ROOT/gitconfig"
mkdir -p "$HOME"
git config --global user.name "Sync Test"
git config --global user.email "sync-test@example.invalid"

SOURCE="$TMP_ROOT/source"
REMOTE="$TMP_ROOT/private-ai-skills.git"
VERIFY="$TMP_ROOT/verify"

git init --bare --initial-branch=main "$REMOTE" >/dev/null

mkdir -p "$SOURCE/skill_alpha/evals"
cat >"$SOURCE/skill_alpha/SKILL.md" <<'EOF'
---
name: alpha
description: test skill
---
EOF
printf '%s\n' '{"ok":true}' >"$SOURCE/skill_alpha/evals/benchmark.jsonl"
printf '%s\n' 'mac artifact' >"$SOURCE/.DS_Store"

first_output="$(AI_NOW_SKILLS_DIR="$SOURCE" PRIVATE_AI_SKILLS_REPO_URL="$REMOTE" "$SCRIPT")"
printf '%s\n' "$first_output" | grep -q '^Pushed ai-now skills: '

git clone --quiet "$REMOTE" "$VERIFY"

[[ -f "$VERIFY/ai-now/skill_alpha/SKILL.md" ]] || {
    echo "expected SKILL.md to be synced" >&2
    exit 1
}

[[ -f "$VERIFY/ai-now/skill_alpha/evals/benchmark.jsonl" ]] || {
    echo "expected package files to be synced" >&2
    exit 1
}

[[ ! -e "$VERIFY/ai-now/.DS_Store" ]] || {
    echo "expected .DS_Store to be excluded" >&2
    exit 1
}

[[ "$(git -C "$VERIFY" branch --show-current)" == "main" ]] || {
    echo "expected first sync to create main" >&2
    exit 1
}

[[ "$(git -C "$VERIFY" log -1 --format=%s)" == "chore: sync ai-now skills" ]] || {
    echo "expected conventional sync commit message" >&2
    exit 1
}

mkdir -p "$VERIFY/other" "$VERIFY/ai-now/skill_stale"
printf '%s\n' 'keep' >"$VERIFY/other/keep.txt"
printf '%s\n' 'stale' >"$VERIFY/ai-now/skill_stale/SKILL.md"
git -C "$VERIFY" add other ai-now/skill_stale
git -C "$VERIFY" commit --quiet -m "test: seed unrelated and stale content"
git -C "$VERIFY" push --quiet origin main

printf '%s\n' 'updated' >>"$SOURCE/skill_alpha/SKILL.md"
AI_NOW_SKILLS_DIR="$SOURCE" PRIVATE_AI_SKILLS_REPO_URL="$REMOTE" "$SCRIPT" >/dev/null
git -C "$VERIFY" pull --quiet --ff-only

[[ -f "$VERIFY/other/keep.txt" ]] || {
    echo "expected unrelated repository content to be preserved" >&2
    exit 1
}

[[ ! -e "$VERIFY/ai-now/skill_stale" ]] || {
    echo "expected stale skill directory to be deleted" >&2
    exit 1
}

grep -qxF 'updated' "$VERIFY/ai-now/skill_alpha/SKILL.md" || {
    echo "expected changed skill content to be synced" >&2
    exit 1
}

head_before_noop="$(git -C "$VERIFY" rev-parse HEAD)"
noop_output="$(AI_NOW_SKILLS_DIR="$SOURCE" PRIVATE_AI_SKILLS_REPO_URL="$REMOTE" "$SCRIPT")"
printf '%s\n' "$noop_output" | grep -q '^No ai-now skill changes: '
head_after_noop="$(git --git-dir="$REMOTE" rev-parse refs/heads/main)"
[[ "$head_before_noop" == "$head_after_noop" ]] || {
    echo "expected no-op sync to avoid an empty commit" >&2
    exit 1
}

git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/missing
detached_head_output="$(AI_NOW_SKILLS_DIR="$SOURCE" PRIVATE_AI_SKILLS_REPO_URL="$REMOTE" "$SCRIPT")"
printf '%s\n' "$detached_head_output" | grep -q '^No ai-now skill changes: '
git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/main

DEFAULT_HOME="$TMP_ROOT/default-home"
DEFAULT_SOURCE="$DEFAULT_HOME/ai-now/skills-active"
DEFAULT_REMOTE="$TMP_ROOT/default-private-ai-skills.git"
mkdir -p "$DEFAULT_SOURCE/skill_beta"
cat >"$DEFAULT_SOURCE/skill_beta/SKILL.md" <<'EOF'
---
name: beta
description: default source test skill
---
EOF

git init --bare --initial-branch=main "$DEFAULT_REMOTE" >/dev/null
HOME="$DEFAULT_HOME" PRIVATE_AI_SKILLS_REPO_URL="$DEFAULT_REMOTE" "$SCRIPT" >/dev/null
git clone --quiet "$DEFAULT_REMOTE" "$TMP_ROOT/default-verify"

[[ -f "$TMP_ROOT/default-verify/ai-now/skill_beta/SKILL.md" ]] || {
    echo "expected default skills-active source to be synced" >&2
    exit 1
}

if AI_NOW_SKILLS_DIR="$TMP_ROOT/missing" PRIVATE_AI_SKILLS_REPO_URL="$REMOTE" "$SCRIPT" >/dev/null 2>&1; then
    echo "expected missing source directory to fail" >&2
    exit 1
fi

REJECT_REMOTE="$TMP_ROOT/reject-private-ai-skills.git"
git init --bare --initial-branch=main "$REJECT_REMOTE" >/dev/null
cat >"$REJECT_REMOTE/hooks/pre-receive" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$REJECT_REMOTE/hooks/pre-receive"

if AI_NOW_SKILLS_DIR="$SOURCE" PRIVATE_AI_SKILLS_REPO_URL="$REJECT_REMOTE" "$SCRIPT" >/dev/null 2>&1; then
    echo "expected rejected push to fail" >&2
    exit 1
fi

echo "test_sync_ai_now_skills: OK"
