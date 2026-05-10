#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPL="$ROOT/.chezmoiscripts/run_onchange_after_07a_install-mise.sh.tmpl"

require_cmd() {
    command -v "$1" >/dev/null 2>&1
}

require_cmd chezmoi || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mise-installer-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
mkdir -p "$HOME/.config/chezmoi"
export XDG_CONFIG_HOME="$HOME/.config"

cat >"$HOME/.config/chezmoi/chezmoi.toml" <<'EOF'
[data]
skipNix = false
EOF

RENDERED="$TMP_ROOT/mise-installer.sh"
chezmoi execute-template \
    --config "$HOME/.config/chezmoi/chezmoi.toml" \
    --source "$ROOT" \
    --override-data '{"versions":{"miseVersion":"v2025.12.0","miseInstallerSha256":"abc123"}}' \
    <"$TMPL" >"$RENDERED"
chmod +x "$RENDERED"

BIN="$TMP_ROOT/bin"
mkdir -p "$BIN"

CURL_LOG="$TMP_ROOT/curl.log"
MISE_LOG="$TMP_ROOT/mise.log"

cat >"$BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

out=""
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
    if [[ "${args[$i]}" == "-o" ]]; then
        out="${args[$((i + 1))]}"
        break
    fi
    i=$((i + 1))
done

if [[ -z "$out" ]]; then
    echo "curl stub expected -o <file>" >&2
    exit 2
fi

echo "curl $*" >>"${MISE_TEST_CURL_LOG:?}"
cat >"$out" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
echo "MISE_VERSION=${MISE_VERSION:-}" >>"${MISE_TEST_LOG:?}"
echo "MISE_INSTALL_PATH=${MISE_INSTALL_PATH:-}" >>"${MISE_TEST_LOG:?}"
mkdir -p "$(dirname "${MISE_INSTALL_PATH:?}")"
cat >"${MISE_INSTALL_PATH}" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "version" ]]; then
    echo "v2025.12.0"
    exit 0
fi
exit 0
INNER
chmod +x "${MISE_INSTALL_PATH}"
EOS
EOF

cat >"$BIN/sha256sum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "${MISE_TEST_SHA256:?}  ${1:-}"
EOF

cat >"$BIN/shasum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "${MISE_TEST_SHA256:?}  ${3:-}"
EOF

chmod +x "$BIN/curl" "$BIN/sha256sum" "$BIN/shasum"

export PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin"
export MISE_TEST_CURL_LOG="$CURL_LOG"
export MISE_TEST_LOG="$MISE_LOG"
export MISE_TEST_SHA256="abc123"

bash "$RENDERED" >/dev/null 2>&1

grep -qxF 'MISE_VERSION=v2025.12.0' "$MISE_LOG" || {
    echo "expected installer to receive pinned MISE_VERSION" >&2
    cat "$MISE_LOG" >&2
    exit 1
}

grep -qxF "MISE_INSTALL_PATH=$HOME/.local/bin/mise" "$MISE_LOG" || {
    echo "expected installer to receive default install path" >&2
    cat "$MISE_LOG" >&2
    exit 1
}

if [[ ! -x "$HOME/.local/bin/mise" ]]; then
    echo "expected mise binary at \$HOME/.local/bin/mise" >&2
    exit 1
fi

# Second run should short-circuit on pinned version match.
bash "$RENDERED" >/dev/null 2>&1

if [[ "$(wc -l <"$CURL_LOG")" -ne 1 ]]; then
    echo "expected installer download to run once" >&2
    cat "$CURL_LOG" >&2
    exit 1
fi

echo "test_mise_installer: OK"
