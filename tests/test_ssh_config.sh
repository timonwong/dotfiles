#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v chezmoi >/dev/null 2>&1 || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ssh-config-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"

CREATE_TEMPLATE="$ROOT/private_dot_ssh/create_config.tmpl"
DEFAULTS="$ROOT/private_dot_ssh/config.d/10-defaults.conf"
ARTIFACT="$TMP_ROOT/apply-home/.ssh/config"

if [[ -e "$ROOT/private_dot_ssh/config.tmpl" ]]; then
    echo "ssh config must use create_config.tmpl so existing local lines are kept" >&2
    exit 1
fi

[[ -f "$CREATE_TEMPLATE" ]] || {
    echo "missing $CREATE_TEMPLATE" >&2
    exit 1
}
[[ -f "$DEFAULTS" ]] || {
    echo "missing $DEFAULTS" >&2
    exit 1
}

grep -q 'Include ~/.ssh/config.d/\*.conf' "$CREATE_TEMPLATE" || {
    echo "create_config.tmpl must include ~/.ssh/config.d/*.conf" >&2
    exit 1
}
grep -q 'Include ~/.ssh/hosts.d/\*.conf' "$CREATE_TEMPLATE" || {
    echo "create_config.tmpl must include ~/.ssh/hosts.d/*.conf" >&2
    exit 1
}
grep -q 'Include ~/.orbstack/ssh/config' "$CREATE_TEMPLATE" || {
    echo "create_config.tmpl must keep the OrbStack include" >&2
    exit 1
}

grep -q '^Host \*$' "$DEFAULTS" || {
    echo "managed ssh defaults must define Host *" >&2
    exit 1
}
grep -q 'ServerAliveInterval 60' "$DEFAULTS" || {
    echo "managed ssh defaults must set ServerAliveInterval" >&2
    exit 1
}
if grep -q 'IdentityFile' "$DEFAULTS"; then
    echo "managed ssh defaults must not pin IdentityFile" >&2
    exit 1
fi

APPLY_SOURCE="$TMP_ROOT/apply-source"
APPLY_HOME="$TMP_ROOT/apply-home"
APPLY_CONFIG="$TMP_ROOT/apply-chezmoi.toml"
mkdir -p "$APPLY_SOURCE/private_dot_ssh/config.d" "$APPLY_HOME/.ssh"
cp "$CREATE_TEMPLATE" "$APPLY_SOURCE/private_dot_ssh/create_config.tmpl"
cp "$DEFAULTS" "$APPLY_SOURCE/private_dot_ssh/config.d/10-defaults.conf"
cat >"$APPLY_CONFIG" <<EOF
sourceDir = "$APPLY_SOURCE"
destDir = "$APPLY_HOME"
EOF

existing_config='# local ssh config
Host *
    IdentityFile ~/.ssh/main
    ServerAliveInterval 30
Include ~/.ssh/hosts.d/*.conf
'
printf '%s' "$existing_config" >"$APPLY_HOME/.ssh/config"

chezmoi --config "$APPLY_CONFIG" \
    --persistent-state "$TMP_ROOT/apply-existing.boltdb" \
    apply --force >/dev/null

if ! grep -q 'IdentityFile ~/.ssh/main' "$APPLY_HOME/.ssh/config"; then
    echo "existing IdentityFile was overwritten" >&2
    cat "$APPLY_HOME/.ssh/config" >&2
    exit 1
fi
if ! grep -q 'ServerAliveInterval 30' "$APPLY_HOME/.ssh/config"; then
    echo "existing Host * values were overwritten" >&2
    cat "$APPLY_HOME/.ssh/config" >&2
    exit 1
fi
grep -q 'ServerAliveInterval 60' "$APPLY_HOME/.ssh/config.d/10-defaults.conf" || {
    echo "managed ssh defaults were not applied to config.d" >&2
    exit 1
}

FRESH_HOME="$TMP_ROOT/fresh-home"
FRESH_CONFIG="$TMP_ROOT/fresh-chezmoi.toml"
mkdir -p "$FRESH_HOME"
cat >"$FRESH_CONFIG" <<EOF
sourceDir = "$APPLY_SOURCE"
destDir = "$FRESH_HOME"
EOF

chezmoi --config "$FRESH_CONFIG" \
    --persistent-state "$TMP_ROOT/apply-fresh.boltdb" \
    apply --force >/dev/null

cp "$FRESH_HOME/.ssh/config" "$TMP_ROOT/fresh-ssh-config"
grep -q 'Include ~/.ssh/config.d/\*.conf' "$FRESH_HOME/.ssh/config" || {
    echo "new ssh config is missing config.d include" >&2
    cat "$FRESH_HOME/.ssh/config" >&2
    exit 1
}
grep -q 'Include ~/.ssh/hosts.d/\*.conf' "$FRESH_HOME/.ssh/config" || {
    echo "new ssh config is missing hosts.d include" >&2
    cat "$FRESH_HOME/.ssh/config" >&2
    exit 1
}
if grep -q 'IdentityFile' "$FRESH_HOME/.ssh/config"; then
    echo "new ssh config must not pin IdentityFile" >&2
    cat "$FRESH_HOME/.ssh/config" >&2
    exit 1
fi

echo "test_ssh_config: OK ($ARTIFACT)"
