# op plugin run cheatsheet

## Wrapper usage

```bash
scripts/op-plugin-gate.sh -- gh auth status
scripts/op-plugin-gate.sh -- glab mr list --output json
```

## Behavior

- tmux missing: runs direct `op plugin run -- ...`
- tmux present: runs in `op-auth` session and attaches/switches there
- tmux setup failure: falls back to direct run

## Notes

- Wrapper output is command output; no JSON status payload.
- Unsupported old flags were removed.
