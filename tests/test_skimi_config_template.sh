#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPL="$ROOT/private_dot_config/skimi/skills.yaml.tmpl"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

render_skimi_config() {
    chezmoi execute-template --source "$ROOT" "$@" <"$TMPL"
}

unmanaged_rendered="$(render_skimi_config --override-data '{"nowledgeMemManaged":false}')"
printf '%s\n' "$unmanaged_rendered" | grep -qxF '  - local_path: ~/.config/skimi/ai-now' || {
    echo "expected ai-now local_path when nowledgeMemManaged=false" >&2
    printf '%s\n' "$unmanaged_rendered" >&2
    exit 1
}

managed_rendered="$(render_skimi_config --override-data '{"nowledgeMemManaged":true}')"
if printf '%s\n' "$managed_rendered" | grep -qxF '  - local_path: ~/.config/skimi/ai-now'; then
    echo "expected ai-now local_path to be omitted when nowledgeMemManaged=true" >&2
    printf '%s\n' "$managed_rendered" >&2
    exit 1
fi

echo "test_skimi_config_template: OK"
