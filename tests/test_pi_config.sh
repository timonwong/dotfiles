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

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pi-config-test.XXXXXX")"
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

SETTINGS_TEMPLATE="$ROOT/dot_pi/agent/modify_settings.json"
KEYBINDINGS_SOURCE="$ROOT/dot_pi/agent/keybindings.json"

render_settings() {
    printf '%s' "$1" | chezmoi execute-template \
        --config "$CONFIG" \
        --source "$SOURCE_ROOT" \
        --persistent-state "$TMP_ROOT/render-state.boltdb" \
        --with-stdin \
        --file "$SETTINGS_TEMPLATE"
}

existing_settings='{
  "lastChangelogVersion": "0.84.1",
  "theme": "light",
  "packages": ["user-package"],
  "defaultProvider": "user-provider",
  "defaultModel": "user-model",
  "defaultThinkingLevel": "medium",
  "customSetting": true
}'

rendered_settings="$(render_settings "$existing_settings")"
printf '%s' "$rendered_settings" | jq -e '
  .theme == "dark" and
  (.packages | length) == 16 and
  (.packages | index("npm:pi-effort")) == null and
  (.packages | index("npm:@narumitw/pi-btw")) == null and
  (.packages | index("npm:@fradser/pi-btw")) != null and
  (.packages | index("npm:@99percentpeople/pi-thinking-fold")) == null and
  (.packages | index("npm:pi-vision-handoff")) == null and
  (.packages | index("npm:@fradser/pi-vision")) != null and
  (.packages | index("npm:@fradser/pi-monitor")) != null and
  (.packages | index("npm:@fradser/pi-utils")) != null and
  (.packages | index("npm:@fradser/pi-agent-teams")) != null and
  .lastChangelogVersion == "0.84.1" and
  .defaultProvider == "user-provider" and
  .defaultModel == "user-model" and
  .defaultThinkingLevel == "medium" and
  .retry.maxRetries == 5 and
  .retry.baseDelayMs == 5000 and
  .steeringMode == "all" and
  .followUpMode == "all" and
  .customSetting == true
' >/dev/null

empty_settings="$(render_settings "")"
printf '%s' "$empty_settings" | jq -e '
  (.theme == "dark") and
  ((.packages | length) == 16) and
  (has("lastChangelogVersion") | not) and
  (has("defaultProvider") | not) and
  (has("defaultModel") | not) and
  (has("defaultThinkingLevel") | not) and
  .retry.maxRetries == 5 and
  .retry.baseDelayMs == 5000 and
  .steeringMode == "all" and
  .followUpMode == "all"
' >/dev/null

jq -e '."app.interrupt" == "ctrl+shift+c"' "$KEYBINDINGS_SOURCE" >/dev/null

if [[ -e "$ROOT/dot_pi/agent/modify_models.json" ]]; then
    echo "chezmoi must not manage ~/.pi/agent/models.json" >&2
    exit 1
fi

if [[ -e "$ROOT/.chezmoidata/pi-models.yaml" ]]; then
    echo "pi-models.yaml must not remain after unmanaging models.json" >&2
    exit 1
fi

if [[ -e "$ROOT/tests/fixtures/pi_models_manifest.json" ]]; then
    echo "pi models manifest fixture must not remain after unmanaging models.json" >&2
    exit 1
fi

existing_models='{
  "customRoot": true,
  "providers": {
    "other": {
      "apiKey": "other-key",
      "custom": true
    },
    "magpie": {
      "api": "openai-completions",
      "customProviderField": "keep-magpie",
      "models": [
        {
          "id": "user-model",
          "custom": true
        }
      ]
    }
  }
}'

# Exercise the actual modify_ target type in an isolated destination.
APPLY_SOURCE="$TMP_ROOT/apply-source"
APPLY_HOME="$TMP_ROOT/apply-home"
APPLY_CONFIG="$TMP_ROOT/apply-chezmoi.toml"
mkdir -p "$APPLY_SOURCE/dot_pi/agent" "$APPLY_HOME/.pi/agent"
cp "$SETTINGS_TEMPLATE" "$APPLY_SOURCE/dot_pi/agent/modify_settings.json"
cp "$KEYBINDINGS_SOURCE" "$APPLY_SOURCE/dot_pi/agent/keybindings.json"
cat >"$APPLY_CONFIG" <<EOF
sourceDir = "$APPLY_SOURCE"
destDir = "$APPLY_HOME"
EOF
printf '%s' "$existing_settings" >"$APPLY_HOME/.pi/agent/settings.json"
printf '%s' "$existing_models" >"$APPLY_HOME/.pi/agent/models.json"
chezmoi --config "$APPLY_CONFIG" \
    --persistent-state "$TMP_ROOT/apply-state.boltdb" \
    apply --force >/dev/null

jq -e '
  .theme == "dark" and
  .defaultProvider == "user-provider" and
  .defaultModel == "user-model" and
  .defaultThinkingLevel == "medium" and
  .retry.maxRetries == 5 and
  .retry.baseDelayMs == 5000 and
  .steeringMode == "all" and
  .followUpMode == "all" and
  .customSetting == true
' "$APPLY_HOME/.pi/agent/settings.json" >/dev/null

jq -e '."app.interrupt" == "ctrl+shift+c"' "$APPLY_HOME/.pi/agent/keybindings.json" >/dev/null

if ! cmp -s <(printf '%s' "$existing_models") "$APPLY_HOME/.pi/agent/models.json"; then
    echo "isolated apply rewrote unmanaged models.json" >&2
    diff -u <(printf '%s' "$existing_models") "$APPLY_HOME/.pi/agent/models.json" >&2 || true
    exit 1
fi

if rg -q --fixed-strings 'onepasswordRead' "$ROOT/dot_pi"; then
    echo "onepasswordRead leaked into Pi source state" >&2
    exit 1
fi

echo "test_pi_config: OK"
