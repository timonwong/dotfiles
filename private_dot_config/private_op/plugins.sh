# shellcheck disable=all

if command -v locale >/dev/null 2>&1; then
    export OP_PLUGIN_ALIASES_SOURCED=1
    alias glab="op plugin run -- glab"
fi
