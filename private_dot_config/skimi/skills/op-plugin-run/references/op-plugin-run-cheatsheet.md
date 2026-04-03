# op plugin run cheatsheet

## Wrapper usage

```bash
# resolve wrapper first, then run
<resolved-wrapper> -- gh auth status
<resolved-wrapper> -- glab mr list --output json
```

## Behavior

- tmux missing: runs direct `op plugin run -- ...`
- tmux present: runs in `op-auth` session and attaches/switches there
- tmux setup failure: falls back to direct run

## Notes

- Wrapper output is command output; no JSON status payload.
- Unsupported old flags were removed.
- If wrapper cannot be resolved as executable, stop; do not run bare `gh`/`glab`.
