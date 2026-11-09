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

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/glab-config-test.XXXXXX")"
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
headless = true
EOF

printf '{{ .chezmoi.stdin | fromYaml | toJson }}\n' >"$TMP_ROOT/yaml2json.tmpl"

TEMPLATE="$ROOT/private_dot_config/glab-cli/modify_private_config.yml"
MANAGED_YAML="$ROOT/.chezmoitemplates/glab-cli/config.yml.tmpl"
ARTIFACT="$TMP_ROOT/rendered-glab-config.yml"

if [[ -e "$ROOT/private_dot_config/glab-cli/private_config.yml.tmpl" ]]; then
    echo "regular glab config.yml template must be replaced by modify_private_config.yml" >&2
    exit 1
fi

grep -Fq "Set your desired Markdown renderer style" "$MANAGED_YAML" || {
    echo "glab managed YAML must keep the original config comments" >&2
    exit 1
}

mkdir -p "$SOURCE_ROOT/.chezmoitemplates/glab-cli"
cp "$MANAGED_YAML" "$SOURCE_ROOT/.chezmoitemplates/glab-cli/config.yml.tmpl"

yaml_to_json() {
    printf '%s' "$1" | chezmoi execute-template \
        --config "$CONFIG" \
        --source "$SOURCE_ROOT" \
        --persistent-state "$TMP_ROOT/yaml2json-state.boltdb" \
        --with-stdin \
        --file "$TMP_ROOT/yaml2json.tmpl"
}

render_config() {
    printf '%s' "$1" | chezmoi execute-template \
        --config "$CONFIG" \
        --source "$SOURCE_ROOT" \
        --persistent-state "$TMP_ROOT/render-state.boltdb" \
        --override-data '{"headless":true}' \
        --with-stdin \
        --file "$TEMPLATE"
}

existing_config='git_protocol: https
glamour_style: auto
glamour_style_auto_migrated: "true"
last_seen_version: v1.117.0
hosts:
  gitlab.com:
    token: keep-gitlab-token
    user: local-user
  gitlab-ce.alauda.cn:
    token: keep-alauda-token
    user: tpwang
    git_protocol: ssh
  extra.example.com:
    token: keep-extra-token
    user: extra
'

rendered="$(render_config "$existing_config")"
printf '%s' "$rendered" >"$ARTIFACT"

yaml_to_json "$rendered" | jq -e '
  .glamour_style == "dark" and
  .git_protocol == "ssh" and
  .telemetry == false and
  .glamour_style_auto_migrated == "true" and
  .last_seen_version == "v1.117.0" and
  .hosts["gitlab.com"].token == "keep-gitlab-token" and
  .hosts["gitlab.com"].user == "local-user" and
  .hosts["gitlab.com"].api_host == "gitlab.com" and
  .hosts["gitlab-ce.alauda.cn"].token == "keep-alauda-token" and
  .hosts["gitlab-ce.alauda.cn"].user == "tpwang" and
  .hosts["gitlab-ce.alauda.cn"].git_protocol == "https" and
  .hosts["gitlab-ce.alauda.cn"].api_host == "gitlab-ce.alauda.cn" and
  (.hosts["gitlab-ce.alauda.cn"] | has("use_keyring")) and
  .hosts["extra.example.com"].token == "keep-extra-token" and
  .hosts["code.alauda.io"].api_host == "code.alauda.io" and
  (.hosts["gitlab.com"] | has("token"))
' >/dev/null

empty_rendered="$(render_config "")"
yaml_to_json "$empty_rendered" | jq -e '
  .glamour_style == "dark" and
  .git_protocol == "ssh" and
  .hosts["gitlab.com"].api_host == "gitlab.com" and
  (.hosts["gitlab.com"] | has("token") | not) and
  (.hosts["gitlab-ce.alauda.cn"] | has("user") | not)
' >/dev/null

APPLY_SOURCE="$TMP_ROOT/apply-source"
APPLY_HOME="$TMP_ROOT/apply-home"
APPLY_CONFIG="$TMP_ROOT/apply-chezmoi.toml"
mkdir -p "$APPLY_SOURCE/private_dot_config/glab-cli" "$APPLY_SOURCE/.chezmoitemplates/glab-cli" "$APPLY_HOME/.config/glab-cli"
cp "$TEMPLATE" "$APPLY_SOURCE/private_dot_config/glab-cli/modify_private_config.yml"
cp "$MANAGED_YAML" "$APPLY_SOURCE/.chezmoitemplates/glab-cli/config.yml.tmpl"
cat >"$APPLY_CONFIG" <<EOF
sourceDir = "$APPLY_SOURCE"
destDir = "$APPLY_HOME"
[data]
headless = true
EOF
printf '%s' "$existing_config" >"$APPLY_HOME/.config/glab-cli/config.yml"
chezmoi --config "$APPLY_CONFIG" \
    --persistent-state "$TMP_ROOT/apply-state.boltdb" \
    apply --force >/dev/null

yaml_to_json "$(cat "$APPLY_HOME/.config/glab-cli/config.yml")" | jq -e '
  .glamour_style == "dark" and
  .hosts["gitlab-ce.alauda.cn"].token == "keep-alauda-token" and
  .hosts["gitlab-ce.alauda.cn"].user == "tpwang" and
  .last_seen_version == "v1.117.0"
' >/dev/null

echo "test_glab_config: OK ($ARTIFACT)"
