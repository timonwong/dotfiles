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
mkdir -p "$SOURCE_ROOT/.chezmoidata" "$(dirname "$CONFIG")"
cp "$ROOT/.chezmoidata/pi-models.yaml" "$SOURCE_ROOT/.chezmoidata/pi-models.yaml"

cat >"$CONFIG" <<'EOF'
[data]
EOF

SETTINGS_TEMPLATE="$ROOT/dot_pi/agent/modify_settings.json"
MODELS_TEMPLATE="$ROOT/dot_pi/agent/modify_models.json"
EXPECTED_MODELS_MANIFEST="$ROOT/tests/fixtures/pi_models_manifest.json"

render_settings() {
    printf '%s' "$1" | chezmoi execute-template \
        --config "$CONFIG" \
        --source "$SOURCE_ROOT" \
        --persistent-state "$TMP_ROOT/render-state.boltdb" \
        --with-stdin \
        --file "$SETTINGS_TEMPLATE"
}

render_models() {
    printf '%s' "$1" | chezmoi execute-template \
        --config "$CONFIG" \
        --source "$SOURCE_ROOT" \
        --persistent-state "$TMP_ROOT/models-render-state.boltdb" \
        --with-stdin \
        --file "$MODELS_TEMPLATE"
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
  .retry.baseDelayMs == 5000
' >/dev/null

existing_models='{
  "customRoot": true,
  "providers": {
    "other": {
      "apiKey": "other-key",
      "custom": true
    },
    "cpa": {
      "apiKey": "user-api-key",
      "baseUrl": "http://localhost:old/v1",
      "customProviderField": "keep",
      "models": [
        {
          "id": "user-model",
          "custom": true
        }
      ]
    },
    "magpie": {
      "customProviderField": "keep-magpie"
    }
  }
}'

rendered_models="$(render_models "$existing_models")"
printf '%s' "$rendered_models" | jq -e '
  .customRoot == true and
  .providers.other.apiKey == "other-key" and
  .providers.other.custom == true and
  .providers.cpa.apiKey == "user-api-key" and
  .providers.cpa.baseUrl == "http://localhost:old/v1" and
  .providers.cpa.customProviderField == "keep" and
  (.providers.cpa | has("compact") | not) and
  (.providers.cpa.models | length) == 1 and
  .providers.cpa.models[0].id == "user-model" and
  .providers.cpa.models[0].custom == true
' >/dev/null

printf '%s' "$rendered_models" | jq -e '
  .providers.magpie.apiKey == "magpie" and
  .providers.magpie.baseUrl == "http://127.0.0.1:3425/v1" and
  .providers.magpie.api == "openai-responses" and
  .providers.magpie.customProviderField == "keep-magpie" and
  (.providers.magpie | has("groupDefaults") | not) and
  (has("catalog") | not) and
  ([.providers.magpie.models[].id | select(startswith("alauda/"))] | length) == 17 and
  ([.providers.magpie.models[].id | select(startswith("group/"))] | length) == 7 and
  (.providers.magpie.models | map(.id) | index("alauda/gpt-5.4")) != null and
  (.providers.magpie.models | map(.id) | index("group/auto-gpt-5-6-sol")) != null and
  (.providers.magpie.models | map(.id) | index("group/auto-gpt-6-1-sol")) != null and
  (.providers.magpie.models | map(.id) | index("group/auto-gpt-6-sol")) != null and
  (.providers.magpie.models | map(.id) | index("group/auto-gpt-6-luna")) != null and
  ([.providers.magpie.models[] | select(.id | startswith("group/")) |
    .contextWindow == 922000 and
    .maxTokens == 128000 and
    .reasoning == true] | all) and
  (.providers.magpie.models | map(select(.id == "group/auto-gpt-5-5")) | first |
    .thinkingLevelMap.max) == null and
  (.providers.magpie.models | map(select(.id == "group/auto-gpt-6-1-sol")) | first |
    .name) == "GPT-6.1-Sol · routing group"
' >/dev/null

empty_models="$(render_models "")"
printf '%s' "$empty_models" | jq -e '
  (.providers | has("cpa") | not) and
  .providers.magpie.apiKey == "magpie" and
  (.providers.magpie.models | length) == 31 and
  (has("catalog") | not)
' >/dev/null

# Exercise the actual modify_ target type in an isolated destination.
APPLY_SOURCE="$TMP_ROOT/apply-source"
APPLY_HOME="$TMP_ROOT/apply-home"
APPLY_CONFIG="$TMP_ROOT/apply-chezmoi.toml"
mkdir -p "$APPLY_SOURCE/.chezmoidata" "$APPLY_SOURCE/dot_pi/agent" "$APPLY_HOME/.pi/agent"
cp "$ROOT/.chezmoidata/pi-models.yaml" "$APPLY_SOURCE/.chezmoidata/pi-models.yaml"
cp "$SETTINGS_TEMPLATE" "$APPLY_SOURCE/dot_pi/agent/modify_settings.json"
cp "$MODELS_TEMPLATE" "$APPLY_SOURCE/dot_pi/agent/modify_models.json"
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
  .customSetting == true
' "$APPLY_HOME/.pi/agent/settings.json" >/dev/null

jq -e '
  .customRoot == true and
  .providers.other.apiKey == "other-key" and
  .providers.cpa.apiKey == "user-api-key" and
  .providers.cpa.customProviderField == "keep" and
  .providers.cpa.baseUrl == "http://localhost:old/v1" and
  (.providers.cpa | has("compact") | not) and
  (.providers.cpa.models | length) == 1 and
  .providers.cpa.models[0].id == "user-model" and
  .providers.magpie.apiKey == "magpie" and
  .providers.magpie.baseUrl == "http://127.0.0.1:3425/v1" and
  ([.providers.magpie.models[].id | select(startswith("group/"))] | length) == 7 and
  (.providers.magpie.models | map(.id) | index("group/auto-gpt-5-6-terra")) != null and
  (.providers.magpie.models | map(.id) | index("group/auto-gpt-6-1-sol")) != null and
  ([.providers.magpie.models[] | select(.id | startswith("group/")) |
    .contextWindow == 922000] | all)
' "$APPLY_HOME/.pi/agent/models.json" >/dev/null

ACTUAL_MODELS_MANIFEST="$TMP_ROOT/pi_models_manifest.json"
jq -S '.providers.magpie.api as $providerApi | {
  providerApi: .providers.magpie.api,
  models: [.providers.magpie.models[] as $model | {
    api: ($model.api // $providerApi),
    id: $model.id,
    name: $model.name
  }]
}' "$APPLY_HOME/.pi/agent/models.json" >"$ACTUAL_MODELS_MANIFEST"

if ! cmp -s "$EXPECTED_MODELS_MANIFEST" "$ACTUAL_MODELS_MANIFEST"; then
    diff -u "$EXPECTED_MODELS_MANIFEST" "$ACTUAL_MODELS_MANIFEST" >&2 || true
    exit 1
fi

printf 'pi_models_manifest_sha256=%s\n' "$(shasum -a 256 "$ACTUAL_MODELS_MANIFEST" | awk '{print $1}')"

if rg -q --fixed-strings 'onepasswordRead' "$ROOT/dot_pi"; then
    echo "onepasswordRead leaked into Pi source state" >&2
    exit 1
fi

if rg -q --fixed-strings '"apiKey"' "$MODELS_TEMPLATE"; then
    echo "apiKey must remain user-managed in the models modify template" >&2
    exit 1
fi

echo "test_pi_config: OK"
