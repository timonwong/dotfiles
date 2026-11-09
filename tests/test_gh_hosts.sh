#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

command -v jq >/dev/null 2>&1 || {
    echo "SKIP: jq not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gh-hosts-test.XXXXXX")"
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

printf '{{ .chezmoi.stdin | fromYaml | toJson }}\n' >"$TMP_ROOT/yaml2json.tmpl"

TEMPLATE="$ROOT/private_dot_config/gh/modify_private_hosts.yml"
ARTIFACT="$TMP_ROOT/rendered-gh-hosts.yml"

if [[ -e "$ROOT/private_dot_config/gh/private_hosts.yml.tmpl" ]]; then
    echo "regular hosts.yml template must be replaced by modify_private_hosts.yml" >&2
    exit 1
fi

if grep -q gitUsername "$TEMPLATE"; then
    echo "gh hosts modify template must not template gitUsername" >&2
    exit 1
fi

yaml_to_json() {
    printf '%s' "$1" | chezmoi execute-template \
        --config "$CONFIG" \
        --source "$SOURCE_ROOT" \
        --persistent-state "$TMP_ROOT/yaml2json-state.boltdb" \
        --with-stdin \
        --file "$TMP_ROOT/yaml2json.tmpl"
}

render_hosts() {
    printf '%s' "$1" | chezmoi execute-template \
        --config "$CONFIG" \
        --source "$SOURCE_ROOT" \
        --persistent-state "$TMP_ROOT/render-state.boltdb" \
        --with-stdin \
        --file "$TEMPLATE"
}

existing_hosts='github.com:
  git_protocol: ssh
  users:
    alice:
      oauth_token: fake-token
  user: alice
  oauth_token: fake-token
enterprise.example.com:
  git_protocol: ssh
  user: bob
'

rendered="$(render_hosts "$existing_hosts")"
printf '%s' "$rendered" >"$ARTIFACT"

yaml_to_json "$rendered" | jq -e '
  .["github.com"].git_protocol == "https" and
  .["github.com"].user == "alice" and
  .["github.com"].oauth_token == "fake-token" and
  .["github.com"].users.alice.oauth_token == "fake-token" and
  .["enterprise.example.com"].user == "bob" and
  .["enterprise.example.com"].git_protocol == "ssh"
' >/dev/null

empty_rendered="$(render_hosts "")"
yaml_to_json "$empty_rendered" | jq -e '
  .["github.com"].git_protocol == "https" and
  (.["github.com"] | has("user") | not) and
  (.["github.com"] | has("oauth_token") | not) and
  (.["github.com"] | has("users") | not)
' >/dev/null

APPLY_SOURCE="$TMP_ROOT/apply-source"
APPLY_HOME="$TMP_ROOT/apply-home"
APPLY_CONFIG="$TMP_ROOT/apply-chezmoi.toml"
mkdir -p "$APPLY_SOURCE/private_dot_config/gh" "$APPLY_HOME/.config/gh"
cp "$TEMPLATE" "$APPLY_SOURCE/private_dot_config/gh/modify_private_hosts.yml"
cat >"$APPLY_CONFIG" <<EOF
sourceDir = "$APPLY_SOURCE"
destDir = "$APPLY_HOME"
EOF
printf '%s' "$existing_hosts" >"$APPLY_HOME/.config/gh/hosts.yml"
chezmoi --config "$APPLY_CONFIG" \
    --persistent-state "$TMP_ROOT/apply-state.boltdb" \
    apply --force >/dev/null

yaml_to_json "$(cat "$APPLY_HOME/.config/gh/hosts.yml")" | jq -e '
  .["github.com"].git_protocol == "https" and
  .["github.com"].user == "alice" and
  .["github.com"].oauth_token == "fake-token" and
  .["enterprise.example.com"].user == "bob"
' >/dev/null

echo "test_gh_hosts: OK ($ARTIFACT)"
