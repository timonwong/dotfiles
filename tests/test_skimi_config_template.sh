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

assert_render_contains() {
    local rendered="$1"
    local expected="$2"

    printf '%s\n' "$rendered" | grep -qxF "$expected" || {
        echo "expected rendered skimi config to contain: $expected" >&2
        printf '%s\n' "$rendered" >&2
        exit 1
    }
}

unmanaged_rendered="$(render_skimi_config --override-data '{"nowledgeMemManaged":false}')"
assert_render_contains "$unmanaged_rendered" '  - local_path: ~/.config/skimi/ai-now'
assert_render_contains "$unmanaged_rendered" '  - repo: mattpocock/skills'
assert_render_contains "$unmanaged_rendered" '    target_dir: mattpocock'
assert_render_contains "$unmanaged_rendered" '      - setup-matt-pocock-skills'
assert_render_contains "$unmanaged_rendered" '      - tdd'
assert_render_contains "$unmanaged_rendered" '      - grill-me'

managed_rendered="$(render_skimi_config --override-data '{"nowledgeMemManaged":true}')"
if printf '%s\n' "$managed_rendered" | grep -qxF '  - local_path: ~/.config/skimi/ai-now'; then
    echo "expected ai-now local_path to be omitted when nowledgeMemManaged=true" >&2
    printf '%s\n' "$managed_rendered" >&2
    exit 1
fi
assert_render_contains "$managed_rendered" '  - repo: mattpocock/skills'
assert_render_contains "$managed_rendered" '    target_dir: mattpocock'

echo "test_skimi_config_template: OK"
