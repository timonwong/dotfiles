#!/usr/bin/env bash
set -euo pipefail

source_dir="${AI_NOW_SKILLS_DIR:-$HOME/ai-now/skills-active}"
repo_url="${PRIVATE_AI_SKILLS_REPO_URL:-https://github.com/timonwong/private-ai-skills.git}"
branch="${PRIVATE_AI_SKILLS_BRANCH:-main}"
commit_message="chore: sync ai-now skills"

if [[ ! -d "$source_dir" ]]; then
    echo "Error: source directory not found: $source_dir" >&2
    exit 1
fi

for command_name in git gh rsync; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Error: ${command_name} is required" >&2
        exit 1
    fi
done

gh auth setup-git

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/sync-ai-now-skills.XXXXXX")"
cleanup() {
    rm -rf -- "$tmp_root"
}
trap cleanup EXIT

repo_dir="$tmp_root/private-ai-skills"
target_dir="$repo_dir/ai-now"

git clone --quiet "$repo_url" "$repo_dir"

if git -C "$repo_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
    current_branch="$(git -C "$repo_dir" branch --show-current)"
    if [[ "$current_branch" != "$branch" ]]; then
        echo "Error: cloned branch is ${current_branch:-detached}, expected $branch" >&2
        exit 1
    fi
elif git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git -C "$repo_dir" switch --quiet --track -c "$branch" "origin/$branch"
else
    git -C "$repo_dir" symbolic-ref HEAD "refs/heads/$branch"
fi

mkdir -p "$target_dir"

rsync -a --delete --delete-excluded --exclude '.DS_Store' "$source_dir"/ "$target_dir"/
git -C "$repo_dir" add -A -- ai-now

if git -C "$repo_dir" diff --cached --quiet -- ai-now; then
    echo "No ai-now skill changes: ${source_dir/#$HOME/~} -> ${repo_url}#${branch}:ai-now"
    exit 0
fi

git -C "$repo_dir" diff --cached --check -- ai-now
git -C "$repo_dir" commit --quiet -m "$commit_message"
commit_sha="$(git -C "$repo_dir" rev-parse HEAD)"
git -C "$repo_dir" push --quiet origin "HEAD:refs/heads/$branch"

echo "Pushed ai-now skills: ${commit_sha} (${repo_url}#${branch}:ai-now)"
