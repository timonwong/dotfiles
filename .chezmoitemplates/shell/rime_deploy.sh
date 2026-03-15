# shellcheck shell=bash

deploy_rime() {
    local current_platform="${platform:-}"
    local squirrel_bin="${SQUIRREL_BIN:-/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel}"

    case "$current_platform" in
    linux)
        if command -v ibus >/dev/null 2>&1; then
            if ibus restart >/dev/null 2>&1; then
                echo "    Deployed: ibus restart"
                return 0
            fi
            echo "    Auto deploy failed: ibus restart"
        fi

        if command -v ibus-daemon >/dev/null 2>&1; then
            if ibus-daemon -drx >/dev/null 2>&1; then
                echo "    Deployed: ibus-daemon -drx"
                return 0
            fi
            echo "    Auto deploy failed: ibus-daemon -drx"
        fi

        echo "    Next step: run 'ibus restart' or restart your input method service."
        ;;
    darwin)
        if [[ ! -x "$squirrel_bin" ]]; then
            echo "    Warning: Squirrel reload binary not found: $squirrel_bin"
            echo "    Next step: run '$squirrel_bin --reload' manually."
            return 0
        fi

        if "$squirrel_bin" --reload >/dev/null 2>&1; then
            echo "    Deployed: $squirrel_bin --reload"
            return 0
        fi

        echo "    Warning: Squirrel reload failed: $squirrel_bin --reload"
        echo "    Next step: run '$squirrel_bin --reload' manually."
        ;;
    *)
        echo "    Skipped deploy (unsupported OS: $current_platform)"
        ;;
    esac
}
