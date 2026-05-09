#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPL="$ROOT/.chezmoiscripts/run_onchange_after_07_mise-install.sh.tmpl"

require_cmd() {
    command -v "$1" >/dev/null 2>&1
}

require_cmd chezmoi || {
    echo "SKIP: chezmoi not found" >&2
    exit 0
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mise-fallback-test.XXXXXX")"
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

RENDERED="$TMP_ROOT/mise-install.sh"
chezmoi execute-template --config "$HOME/.config/chezmoi/chezmoi.toml" --source "$ROOT" <"$TMPL" >"$RENDERED"
chmod +x "$RENDERED"

BIN="$TMP_ROOT/bin"
mkdir -p "$BIN"
LOG="$TMP_ROOT/mise.log"

cat >"$BIN/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "mise $*" >>"${MISE_TEST_LOG:?}"

case "${1:-}" in
activate)
    printf 'export PATH="%s"\n' "$PATH"
    ;;
install)
    exit 0
    ;;
reshim)
    exit 0
    ;;
*)
    echo "unexpected mise args: $*" >&2
    exit 2
    ;;
esac
EOF

cat >"$BIN/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF

chmod +x "$BIN/mise" "$BIN/npm"

export MISE_TEST_LOG="$LOG"
export PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin"

bash "$RENDERED" >/dev/null 2>&1

grep -qxF 'mise activate bash' "$LOG" || {
    echo "expected fallback mise activate" >&2
    cat "$LOG" >&2
    exit 1
}

grep -qxF 'mise install --yes' "$LOG" || {
    echo "expected fallback mise install --yes" >&2
    cat "$LOG" >&2
    exit 1
}

grep -qxF 'mise reshim' "$LOG" || {
    echo "expected fallback mise reshim" >&2
    cat "$LOG" >&2
    exit 1
}

if grep -q 'mise install --yes node' "$LOG"; then
    echo "did not expect node bootstrap when npm exists" >&2
    cat "$LOG" >&2
    exit 1
fi

echo "test_mise_install_fallback: OK"
