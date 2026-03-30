#!/usr/bin/env bash
set -euo pipefail

exec python3 - "$@" <<'PY'
import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

ENFORCED_SESSION = "op-auth"
TIMEOUT_EXIT = 124
BLOCKED_EXIT = 20
MAX_OUTPUT_CHARS = 4000

def parse_cli(argv):
    split_idx = None
    for i, token in enumerate(argv):
        if token == "--":
            split_idx = i
            break
    if split_idx is None:
        opt_argv = argv
        target = []
    else:
        opt_argv = argv[:split_idx]
        target = argv[split_idx + 1 :]

    parser = argparse.ArgumentParser(
        prog="op-plugin-gate.sh",
        description="Gate plugin-managed command routing and tmux status.",
        add_help=True,
    )
    parser.add_argument(
        "--plugins-file",
        default=os.path.expanduser("~/.config/op/plugins.sh"),
        help="plugins.sh path",
    )
    parser.add_argument(
        "--session-name",
        default=ENFORCED_SESSION,
        help="tmux session name",
    )
    parser.add_argument(
        "--simulate-tmux-missing",
        action="store_true",
        help="force tmux_missing path",
    )
    parser.add_argument(
        "--simulate-bootstrap-fail",
        action="store_true",
        help="force tmux_bootstrap_failed path",
    )
    parser.add_argument(
        "--timeout-sec",
        type=int,
        default=45,
        help="execution timeout in seconds",
    )
    parser.add_argument(
        "--skip-exec",
        action="store_true",
        help="skip command execution (testing only)",
    )
    args = parser.parse_args(opt_argv)
    if not target:
        parser.print_usage(sys.stderr)
        print("missing target command after --", file=sys.stderr)
        sys.exit(64)
    if args.timeout_sec <= 0:
        parser.print_usage(sys.stderr)
        print("--timeout-sec must be > 0", file=sys.stderr)
        sys.exit(64)
    return args, target[0], target[1:]


CANONICAL_ALIAS_RE = re.compile(
    r'^\s*alias\s+([A-Za-z0-9_.-]+)=([\'"])op\s+plugin\s+run\s+--\s+([A-Za-z0-9_.-]+)\2\s*$'
)
ALIAS_NAME_RE = re.compile(r"^\s*alias\s+([A-Za-z0-9_.-]+)=")


def parse_plugins_file(path, target_cmd):
    managed_commands = []
    seen = set()

    if not os.path.exists(path):
        return {
            "parse_status": "failed",
            "reason": "plugins_file_missing",
            "fix": f'Create {path} with canonical aliases like alias gh="op plugin run -- gh".',
            "managed_commands": managed_commands,
        }
    if not os.access(path, os.R_OK):
        return {
            "parse_status": "failed",
            "reason": "plugins_file_unreadable",
            "fix": f"Fix file permissions for {path} and retry.",
            "managed_commands": managed_commands,
        }

    with open(path, "r", encoding="utf-8") as f:
        for raw_line in f:
            if not re.match(r"^\s*alias\s+", raw_line):
                continue

            alias_candidate = None
            m_name = ALIAS_NAME_RE.match(raw_line)
            if m_name:
                alias_candidate = m_name.group(1)

            m = CANONICAL_ALIAS_RE.match(raw_line)
            if m:
                alias_name, wrapped_cmd = m.group(1), m.group(3)
                if alias_name != wrapped_cmd:
                    return {
                        "parse_status": "failed",
                        "reason": f"alias_name_mismatch:{alias_name}:{wrapped_cmd}",
                        "fix": f'Rewrite alias to canonical form: alias {alias_name}="op plugin run -- {alias_name}".',
                        "managed_commands": managed_commands,
                    }
                if alias_name not in seen:
                    seen.add(alias_name)
                    managed_commands.append(alias_name)
                continue

            if alias_candidate == target_cmd:
                return {
                    "parse_status": "failed",
                    "reason": f"malformed_target_alias:{target_cmd}",
                    "fix": f'Rewrite alias to canonical form: alias {target_cmd}="op plugin run -- {target_cmd}".',
                    "managed_commands": managed_commands,
                }
            if "op plugin run" in raw_line:
                return {
                    "parse_status": "failed",
                    "reason": "malformed_plugin_alias",
                    "fix": 'Fix malformed plugin alias lines to canonical shape alias xxx="op plugin run -- xxx".',
                    "managed_commands": managed_commands,
                }

    if not managed_commands:
        return {
            "parse_status": "failed",
            "reason": "no_valid_managed_alias",
            "fix": f"Add at least one canonical alias to {path}.",
            "managed_commands": managed_commands,
        }

    return {
        "parse_status": "ok",
        "reason": "",
        "fix": "",
        "managed_commands": managed_commands,
    }


def build_base_output(args, target_cmd, target_args, parse_result):
    return {
        "source": "op-plugin-gate.sh",
        "plugins_file": args.plugins_file,
        "enforced_session": ENFORCED_SESSION,
        "target_command": target_cmd,
        "target_args": target_args,
        "managed_commands": parse_result["managed_commands"],
        "managed": target_cmd in parse_result["managed_commands"],
        "parse_status": parse_result["parse_status"],
        "execution_status": "blocked",
        "tmux_mode": "n/a",
        "routed_command": "n/a",
        "reason": parse_result["reason"],
        "degrade_reason": "",
        "tmux_error_summary": "",
        "risk_note": "",
        "run_mode": "skipped",
        "command_status": "skipped",
        "command_exit_code": None,
        "timed_out": False,
        "stdout_snippet": "",
        "stderr_snippet": "",
        "fix": parse_result["fix"],
    }


def degrade(out, mode, reason, tmux_err, risk_note):
    out["execution_status"] = "degraded"
    out["tmux_mode"] = mode
    out["reason"] = reason
    out["degrade_reason"] = reason
    out["tmux_error_summary"] = tmux_err
    out["risk_note"] = risk_note
    return out


def trim_text(text):
    if not text:
        return ""
    if len(text) <= MAX_OUTPUT_CHARS:
        return text
    clipped = text[:MAX_OUTPUT_CHARS]
    remain = len(text) - MAX_OUTPUT_CHARS
    return f"{clipped}\n...[truncated {remain} chars]"


def apply_run_result(out, run):
    out["run_mode"] = run["run_mode"]
    out["command_status"] = run["command_status"]
    out["command_exit_code"] = run["command_exit_code"]
    out["timed_out"] = run["timed_out"]
    out["stdout_snippet"] = trim_text(run["stdout"])
    out["stderr_snippet"] = trim_text(run["stderr"])


def skipped_run(run_mode):
    return {
        "run_mode": run_mode,
        "command_status": "skipped",
        "command_exit_code": None,
        "timed_out": False,
        "stdout": "",
        "stderr": "",
    }


def run_direct(routed, timeout_sec):
    try:
        proc = subprocess.run(
            routed,
            capture_output=True,
            text=True,
            check=False,
            timeout=timeout_sec,
        )
        return {
            "run_mode": "fallback_direct",
            "command_status": "succeeded" if proc.returncode == 0 else "failed",
            "command_exit_code": proc.returncode,
            "timed_out": False,
            "stdout": proc.stdout or "",
            "stderr": proc.stderr or "",
        }
    except subprocess.TimeoutExpired as e:
        return {
            "run_mode": "fallback_direct",
            "command_status": "timeout",
            "command_exit_code": None,
            "timed_out": True,
            "stdout": (e.stdout or "") if isinstance(e.stdout, str) else "",
            "stderr": (e.stderr or "") if isinstance(e.stderr, str) else "",
        }


def ensure_tmux_session(session_name):
    tmux_env = os.environ.copy()
    tmux_env["TERM"] = "xterm-256color"

    has_proc = subprocess.run(
        ["tmux", "has-session", "-t", session_name],
        capture_output=True,
        text=True,
        check=False,
        env=tmux_env,
    )
    if has_proc.returncode == 0:
        return {"ok": True, "error": "", "env": tmux_env}

    ensure_proc = subprocess.run(
        ["tmux", "new-session", "-d", "-s", session_name],
        capture_output=True,
        text=True,
        check=False,
        env=tmux_env,
    )
    if ensure_proc.returncode != 0:
        err = (ensure_proc.stderr or ensure_proc.stdout or has_proc.stderr or has_proc.stdout or "").strip()
        if not err:
            err = f"tmux new-session failed with exit {ensure_proc.returncode}"
        return {"ok": False, "error": err, "env": tmux_env}
    return {"ok": True, "error": "", "env": tmux_env}


def run_in_tmux_session(routed, session_name, timeout_sec):
    ensured = ensure_tmux_session(session_name)
    if not ensured["ok"]:
        return {"ok": False, "error": ensured["error"]}
    tmux_env = ensured["env"]

    with tempfile.TemporaryDirectory(prefix="op-plugin-gate-") as td:
        stdout_file = os.path.join(td, "stdout.txt")
        stderr_file = os.path.join(td, "stderr.txt")
        exit_file = os.path.join(td, "exit_code.txt")

        runner = (
            f"{shlex.join(routed)} >{shlex.quote(stdout_file)} "
            f"2>{shlex.quote(stderr_file)}; "
            f"printf '%s' $? > {shlex.quote(exit_file)}"
        )
        window_proc = subprocess.run(
            [
                "tmux",
                "new-window",
                "-d",
                "-P",
                "-F",
                "#{window_id}",
                "-t",
                session_name,
                f"sh -lc {shlex.quote(runner)}",
            ],
            capture_output=True,
            text=True,
            check=False,
            env=tmux_env,
        )
        if window_proc.returncode != 0:
            err = (window_proc.stderr or window_proc.stdout or "").strip()
            if not err:
                err = f"tmux new-window failed with exit {window_proc.returncode}"
            return {"ok": False, "error": err}

        window_id = (window_proc.stdout or "").strip()
        deadline = time.monotonic() + timeout_sec
        while time.monotonic() < deadline:
            if os.path.exists(exit_file):
                break
            time.sleep(0.1)

        timed_out = not os.path.exists(exit_file)
        if window_id:
            subprocess.run(
                ["tmux", "kill-window", "-t", window_id],
                capture_output=True,
                text=True,
                check=False,
                env=tmux_env,
            )

        if timed_out:
            return {
                "ok": True,
                "run": {
                    "run_mode": "tmux_op-auth",
                    "command_status": "timeout",
                    "command_exit_code": None,
                    "timed_out": True,
                    "stdout": "",
                    "stderr": f"timed out after {timeout_sec}s while running in tmux session {session_name}",
                },
            }

        exit_raw = ""
        if os.path.exists(exit_file):
            with open(exit_file, "r", encoding="utf-8") as f:
                exit_raw = f.read().strip()
        try:
            exit_code = int(exit_raw)
        except ValueError:
            exit_code = 1

        stdout_val = ""
        stderr_val = ""
        if os.path.exists(stdout_file):
            with open(stdout_file, "r", encoding="utf-8", errors="replace") as f:
                stdout_val = f.read()
        if os.path.exists(stderr_file):
            with open(stderr_file, "r", encoding="utf-8", errors="replace") as f:
                stderr_val = f.read()

        return {
            "ok": True,
            "run": {
                "run_mode": "tmux_op-auth",
                "command_status": "succeeded" if exit_code == 0 else "failed",
                "command_exit_code": exit_code,
                "timed_out": False,
                "stdout": stdout_val,
                "stderr": stderr_val,
            },
        }


def final_exit_code(out):
    if out["execution_status"] == "blocked":
        return BLOCKED_EXIT
    if out["command_status"] == "timeout":
        return TIMEOUT_EXIT
    if out["command_status"] == "failed":
        return out["command_exit_code"] if isinstance(out["command_exit_code"], int) else 1
    return 0


def main():
    args, target_cmd, target_args = parse_cli(sys.argv[1:])
    parse_result = parse_plugins_file(args.plugins_file, target_cmd)
    out = build_base_output(args, target_cmd, target_args, parse_result)

    if args.session_name != ENFORCED_SESSION:
        out["execution_status"] = "blocked"
        out["reason"] = f"session_must_be_{ENFORCED_SESSION}"
        out["fix"] = f"Use --session-name {ENFORCED_SESSION} or omit the option."
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return BLOCKED_EXIT

    if parse_result["parse_status"] == "failed":
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return BLOCKED_EXIT

    if not out["managed"]:
        out["execution_status"] = "blocked"
        out["reason"] = f"target_not_managed:{target_cmd}"
        out["fix"] = "Target command is not managed by plugins.sh; this skill is not responsible for forcing routing."
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return BLOCKED_EXIT

    routed = ["op", "plugin", "run", "--", target_cmd, *target_args]
    out["routed_command"] = shlex.join(routed)
    out["fix"] = ""

    if args.simulate_tmux_missing:
        degrade(
            out,
            "unavailable",
            "tmux_missing",
            "simulated tmux missing",
            "Fallback avoids hard stop but can be less stable than tmux session reuse.",
        )
        apply_run_result(out, skipped_run("fallback_direct") if args.skip_exec else run_direct(routed, args.timeout_sec))
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return final_exit_code(out)

    if shutil.which("tmux") is None:
        degrade(
            out,
            "unavailable",
            "tmux_missing",
            "command -v tmux failed",
            "Fallback avoids hard stop but can be less stable than tmux session reuse.",
        )
        apply_run_result(out, skipped_run("fallback_direct") if args.skip_exec else run_direct(routed, args.timeout_sec))
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return final_exit_code(out)

    if args.simulate_bootstrap_fail:
        degrade(
            out,
            "failed",
            "tmux_bootstrap_failed",
            "simulated tmux bootstrap failure",
            "Fallback avoids hard stop but skips stable tmux session path.",
        )
        apply_run_result(out, skipped_run("fallback_direct") if args.skip_exec else run_direct(routed, args.timeout_sec))
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return final_exit_code(out)

    if args.skip_exec:
        ensured = ensure_tmux_session(ENFORCED_SESSION)
        if ensured["ok"]:
            out["execution_status"] = "ready"
            out["tmux_mode"] = ENFORCED_SESSION
            out["reason"] = "tmux_op_auth_ready_skip_exec"
            apply_run_result(out, skipped_run("tmux_op-auth"))
            print(json.dumps(out, ensure_ascii=False, indent=2))
            return final_exit_code(out)
        degrade(
            out,
            "failed",
            "tmux_bootstrap_failed",
            ensured["error"],
            "Fallback avoids hard stop but skips stable tmux session path.",
        )
        apply_run_result(out, skipped_run("fallback_direct"))
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return final_exit_code(out)

    tmux_exec = run_in_tmux_session(routed, ENFORCED_SESSION, args.timeout_sec)
    if tmux_exec["ok"]:
        out["execution_status"] = "ready"
        out["tmux_mode"] = ENFORCED_SESSION
        out["reason"] = "tmux_op_auth_execution"
        apply_run_result(out, tmux_exec["run"])
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return final_exit_code(out)

    degrade(
        out,
        "failed",
        "tmux_bootstrap_failed",
        tmux_exec["error"],
        "Fallback avoids hard stop but skips stable tmux session path.",
    )
    apply_run_result(out, run_direct(routed, args.timeout_sec))
    print(json.dumps(out, ensure_ascii=False, indent=2))
    return final_exit_code(out)


if __name__ == "__main__":
    sys.exit(main())
PY
