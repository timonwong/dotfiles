---
name: op-plugin-run
description: Enforce 1Password shell-plugin execution through `op plugin run`, with mandatory startup parsing of `~/.config/op/plugins.sh` and tmux-stable execution. Use this skill whenever any CLI that should be routed via `op plugin run` such as `gh` and `glab`.
metadata:
  skill-type: infrastructure_ops
---

# Op Plugin Run

Specialized skill for commands that must run behind 1Password Shell Plugins, especially `op plugin run`, with tmux-backed session stability.

## Standards snapshot (March 2026)

- Parse plugin alias source first, then decide command routing.
- Treat `~/.config/op/plugins.sh` as the source of truth for managed commands.
- Keep managed command execution inside tmux to reduce repeated approval prompts.
- Never downgrade a managed command to a bare CLI call.

## When to use

- Any CLI likely wrapped by 1Password plugin aliases such as `gh` and `glab`.

## When not to use

- Task has no 1Password Shell Plugin requirement.
- Command is not listed as managed in `~/.config/op/plugins.sh`.
- Request is about general secret workflows (`op read`, `op inject`, `.env` modeling) rather than plugin-run execution routing.

## Required inputs

- Command and arguments the user wants to run.
- Availability/readability of `~/.config/op/plugins.sh`.
- Whether current shell already runs inside tmux.

## Deliverables

- Parsed managed-command map from `~/.config/op/plugins.sh`.
- Exact safe execution command using `op plugin run -- <command> ...` for managed commands.
- tmux execution path (`existing tmux` or `session op-auth`) for the command.
- Clear stop reason plus fix guidance when parsing preconditions fail.

## Hard constraints

- Session start first step is mandatory: parse `~/.config/op/plugins.sh`.
- If file is missing/unreadable, stop and return repair guidance. Do not guess defaults.
- Only trust alias pattern: `alias xxx="op plugin run -- xxx"`.
- If alias syntax is malformed or ambiguous, stop and report parsing failure.
- Managed commands must never be executed as bare commands.

## Workflow

1. Parse `~/.config/op/plugins.sh` before any command planning.
2. Extract managed commands from aliases matching:
   - `alias <name>="op plugin run -- <name>"`
3. Validate parsing results:
   - File missing/unreadable -> stop with fix steps.
   - Malformed alias for managed candidate -> stop with fix steps.
4. Determine command routing:
   - If target command is managed, route to `op plugin run -- <command> <args>`.
   - If not managed, explicitly state this skill is not responsible for forced routing.
5. Enforce tmux:
   - If already in tmux, continue in current session.
   - If not in tmux, create/attach `op-auth` session first, then run managed command there.
6. Return final execution form and verification checklist.

## Output format

Always return:

```markdown
## Parse result

- plugins_file: <path>
- managed_commands: [cmd1, cmd2]
- parse_status: ok | failed

## Execution path

- tmux_mode: existing | op-auth
- routed_command: <exact command>

## Verification

- check_1: <what to verify>
- check_2: <what to verify>

## If blocked

- reason: <specific failure>
- fix: <concrete repair step>
```

## tmux policy

- Default session name: `op-auth`.
- Prefer reusing an existing tmux session if already inside tmux.
- Outside tmux, use attach-or-create semantics for `op-auth`.
- Keep plugin-managed command and its immediate validation in the same tmux session.

## References

- `references/plugins-sh-parsing.md`
- `references/tmux-execution-policy.md`
- `references/op-plugin-run-cheatsheet.md`

## Examples

- "Run `gh pr checks` with 1Password plugin and avoid extra approvals."
- "Check whether `glab` must be routed through `op plugin run`."
- "My shell keeps re-approving credentials; force stable tmux path for `gh`."

## Failure mode

- If parsing or tmux prerequisites are not met, stop execution planning and return explicit fix guidance. Never provide a bare command path for managed commands.
