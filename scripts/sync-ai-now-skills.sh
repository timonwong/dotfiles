#!/usr/bin/env bash
set -euo pipefail

source_dir="${AI_NOW_SKILLS_DIR:-$HOME/ai-now/skills}"

if [[ -n "${CHEZMOI_SOURCE_DIR:-}" ]]; then
    chezmoi_source_dir="$CHEZMOI_SOURCE_DIR"
elif command -v chezmoi >/dev/null 2>&1; then
    chezmoi_source_dir="$(chezmoi source-path)"
else
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
    chezmoi_source_dir="$(cd -- "$script_dir/.." && pwd -P)"
fi

target_dir="$chezmoi_source_dir/private_dot_config/skimi/ai-now"

if [[ ! -d "$source_dir" ]]; then
    echo "Error: source directory not found: $source_dir" >&2
    exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
    echo "Error: rsync is required" >&2
    exit 1
fi

mkdir -p "$target_dir"

rsync -a --delete --delete-excluded --exclude '.DS_Store' "$source_dir"/ "$target_dir"/
echo "Synced ai-now skills: ${source_dir/#$HOME/~} -> ${target_dir/#$HOME/~}"
