#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPL="$ROOT/private_dot_config/skimi/skills.yaml.tmpl"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skimi-config-template-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
SOURCE_ROOT="$TMP_ROOT/source"
CONFIG="$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
mkdir -p "$SOURCE_ROOT" "$(dirname "$CONFIG")"
cat >"$CONFIG" <<'EOF'
[data]
EOF

render_skimi_config() {
    chezmoi execute-template --config "$CONFIG" --source "$SOURCE_ROOT" "$@" <"$TMPL"
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
assert_render_contains "$unmanaged_rendered" '  - repo: git@github.com:timonwong/private-ai-skills.git'
assert_render_contains "$unmanaged_rendered" '  - repo: mattpocock/skills'
assert_render_contains "$unmanaged_rendered" '    target_dir: mattpocock'
assert_render_contains "$unmanaged_rendered" '      - setup-matt-pocock-skills'
assert_render_contains "$unmanaged_rendered" '      - tdd'
assert_render_contains "$unmanaged_rendered" '      - grill-me'
assert_render_contains "$unmanaged_rendered" '  - repo: git@github.com:timonwong/private-ai-skills.git/alauda'
assert_render_contains "$unmanaged_rendered" '      - builders-publish-errata'
assert_render_contains "$unmanaged_rendered" '        - codex'

managed_rendered="$(render_skimi_config --override-data '{"nowledgeMemManaged":true}')"
if printf '%s\n' "$managed_rendered" | grep -qxF '  - repo: git@github.com:timonwong/private-ai-skills.git'; then
    echo "expected private ai skills repo to be omitted when nowledgeMemManaged=true" >&2
    printf '%s\n' "$managed_rendered" >&2
    exit 1
fi
assert_render_contains "$managed_rendered" '  - repo: mattpocock/skills'
assert_render_contains "$managed_rendered" '    target_dir: mattpocock'
assert_render_contains "$managed_rendered" '  - repo: git@github.com:timonwong/private-ai-skills.git/alauda'
assert_render_contains "$managed_rendered" '      - builders-publish-errata'
assert_render_contains "$managed_rendered" '        - codex'

echo "test_skimi_config_template: OK"
