# plugins.sh parsing policy

This skill treats `~/.config/op/plugins.sh` as required startup input.

## Required file checks

1. File exists.
2. File is readable.
3. File contains at least one valid managed alias line.

If any check fails, stop and return concrete repair guidance.

## Supported alias shape

Only this canonical shape is accepted as managed:

```bash
alias gh="op plugin run -- gh"
alias glab="op plugin run -- glab"
```

Accepted variants:

- Leading/trailing spaces.
- Single or double quotes.

Rejected variants (must fail):

- Missing `--`.
- Different wrapped command from alias name.
- Multi-command alias bodies (`;`, `&&`, pipes).
- Aliases not using `op plugin run`.

## Extraction result

Return:

- `managed_commands`: unique command names extracted from valid aliases.
- `parse_status`: `ok` or `failed`.
- `failure_reason`: set only when failed.

## Failure guidance template

- Missing file: create `~/.config/op/plugins.sh` and define canonical aliases.
- Unreadable file: fix permissions, then retry.
- Malformed alias: rewrite to canonical `alias xxx="op plugin run -- xxx"` form.
