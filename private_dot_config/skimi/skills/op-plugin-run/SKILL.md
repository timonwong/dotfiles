---
name: op-plugin-run
description: Use when CLI commands (such as `gh` or `glab`) may be managed by 1Password shell-plugin aliases and must be routed through `op plugin run` with tmux-first execution and controlled fallback.
metadata:
  skill-type: infrastructure_ops
---

# Op Plugin Run

Specialized skill for commands that must run behind 1Password Shell Plugins, especially `op plugin run`, with tmux-backed session stability.

## Standards snapshot (March 2026)

- Run the gate script as the single entrypoint for both routing and execution.
- Treat `~/.config/op/plugins.sh` as the source of truth for managed commands.
- Enforce managed-command execution in tmux session `op-auth` when tmux path is healthy.
- Allow controlled fallback only when script reports tmux unavailable/bootstrap failed.
- Never downgrade a managed command to a bare CLI call.

## When to use

- Any CLI likely wrapped by 1Password plugin aliases such as `gh` and `glab`.

## When not to use

- Task has no 1Password Shell Plugin requirement.
- Command is not listed as managed in `~/.config/op/plugins.sh`.
- Request is about general secret workflows (`op read`, `op inject`, `.env` modeling) rather than plugin-run execution routing.

## Required inputs

- Command and arguments the user wants to run.
- Gate script path: `scripts/op-plugin-gate.sh`.
- Availability/readability of `~/.config/op/plugins.sh`.
- Optional execution timeout (script `--timeout-sec`).

## Deliverables

- Parsed managed-command map from `~/.config/op/plugins.sh`.
- Execution status: `ready`, `degraded`, or `blocked`.
- Routed command that always keeps managed commands behind `op plugin run --`.
- tmux execution path evidence for managed commands.
- Actual command execution result from script (`command_status`, `command_exit_code`, output snippets).
- Clear stop reason plus fix guidance when parsing preconditions fail.

## Hard constraints

- Session start first step is mandatory: run `scripts/op-plugin-gate.sh -- <command> <args...>`.
- Never skip script execution for managed-command routing decisions.
- Never override script-reported status with natural-language judgment.
- Never execute managed routed command outside gate script after status is computed.
- If script file is missing/unreadable/non-executable, stop and return repair guidance.
- If file is missing/unreadable, stop and return repair guidance. Do not guess defaults.
- Only trust alias pattern: `alias xxx="op plugin run -- xxx"`.
- If alias syntax is malformed or ambiguous, stop and report parsing failure.
- Managed commands must never be executed as bare commands.
- Enforce this execution gate for managed commands from script output:
  - `managed && parse_ok && tmux_enter_ok -> execution_status=ready` and execute in `op-auth`
  - `managed && parse_ok && (tmux_missing || tmux_enter_failed) -> execution_status=degraded`
  - `parse_failed -> execution_status=blocked`
- `degraded` is allowed only for tmux unavailability/failure, not as a convenience path.

## Workflow

1. Run `scripts/op-plugin-gate.sh -- <command> <args...>` before any command planning.
2. Use script JSON output as the single source of truth for:
   - parse status
   - managed status
   - execution status
   - routed command
   - command execution result
3. Apply script result:
   - `execution_status=ready`: command already executed in `op-auth`; report result fields.
   - `execution_status=degraded`: command already executed via fallback; surface `degrade_reason` + `tmux_error_summary` + `risk_note` + result fields.
   - `execution_status=blocked`: stop and return `reason` + `fix`.
4. Never re-run the same managed command outside gate script output handling.
5. Return final execution form and verification checklist.

## Output format

Always return the script JSON result and a Markdown summary derived from it:

```markdown
## Parse result

- plugins_file: <path>
- managed_commands: [cmd1, cmd2]
- parse_status: ok | failed

## Execution path

- execution_status: ready | degraded | blocked
- tmux_mode: op-auth | unavailable | failed | n/a
- routed_command: <exact command or n/a>
- reason: <short reason for current status>

## Run result

- run_mode: tmux_op-auth | fallback_direct | skipped
- command_status: succeeded | failed | timeout | skipped
- command_exit_code: <int or null>
- timed_out: true | false
- stdout_snippet: <captured stdout>
- stderr_snippet: <captured stderr>

## Degraded details (required only when execution_status=degraded)

- degrade_reason: tmux_missing | tmux_bootstrap_failed
- tmux_error_summary: <stderr summary or command failure note>
- risk_note: <why fallback can be less stable>

## Verification

- check_1: <what to verify>
- check_2: <what to verify>

## If blocked

- reason: <specific failure>
- fix: <concrete repair step>
```

Field rules:

- `execution_status=ready` requires non-empty `routed_command`, `tmux_mode=op-auth`, and `run_mode=tmux_op-auth`.
- `execution_status=degraded` requires non-empty `routed_command` and all degraded details fields.
- `execution_status=blocked` requires `routed_command=n/a`.

## tmux policy

- Default session name: `op-auth`.
- Always target `op-auth` for ready-path execution (do not execute in arbitrary current tmux session).
- Use script-evaluated bootstrap semantics for `op-auth`.
- Keep plugin-managed command and its immediate validation in the same tmux session when `ready`.
- If tmux is unavailable or bootstrap fails, fallback is allowed only as `degraded`.

## References

- `references/plugins-sh-parsing.md`
- `references/tmux-execution-policy.md`
- `references/op-plugin-run-cheatsheet.md`
- `references/script-workflow.md`

## Examples

- "Run `gh pr checks` with 1Password plugin and avoid extra approvals."
- "Check whether `glab` must be routed through `op plugin run`."
- "My shell keeps re-approving credentials; force stable tmux path for `gh`."

## Failure mode

- Parse failure is always `blocked`.
- tmux missing/bootstrap failure is `degraded` (not `blocked`) for managed commands.
- Never provide a bare command path (`gh`, `glab`) for managed commands.
- Script exit code follows run result: `blocked=20`, timeout=`124`, otherwise command exit code.

## Forbidden responses

- Do not decide status before running `scripts/op-plugin-gate.sh`.
- Do not output `gh ...` or `glab ...` directly when command is managed.
- Do not claim `ready` without `tmux_mode=op-auth` and run evidence.
- Do not emit `degraded` without an explicit tmux-related failure reason.
- Do not skip parse step, even when command appears obvious.
