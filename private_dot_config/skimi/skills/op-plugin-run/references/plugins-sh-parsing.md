# plugins.sh sourcing policy

This wrapper no longer parses aliases.

Policy:

- If `~/.config/op/plugins.sh` exists, source it.
- If the file does not exist, continue.
- If source fails, print warning and continue.

Command routing is always explicit:

```bash
op plugin run -- <command> [args...]
```
