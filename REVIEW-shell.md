# Review — shell/script.sh

The script should log a timestamped message to stdout. As written it fails: the
redirect targets an undefined variable and word-splitting drops most of the message.

## Bugs

1. **Undefined variable.** `LOG_FILE` is defined but the write uses `$LOGFILE` —
   a different, unset variable. Expands to empty → `>> ""` → ambiguous redirect.

2. **Single quotes block expansion.** `LOG_FILE='$STDOUT'` stores the literal
   text `$STDOUT`, not `/dev/stdout`. Use double quotes.

3. **Unquoted argument splits.** `log_message $LOG_MESSAGE` passes each word
   separately; `$1` gets only `is`, the rest is dropped. Fails silently — the
   worst of the four. Quote it: `log_message "$LOG_MESSAGE"`.

4. **No shebang / no error handling.** Missing `#!/usr/bin/env bash` and
   `set -euo pipefail`, so the interpreter is ambiguous and failures pass unnoticed.

## Corrected

```bash
#!/usr/bin/env bash
set -euo pipefail

STDOUT="/dev/stdout"
LOG_FILE="$STDOUT"
LOG_MESSAGE="is the date, should log to $STDOUT"

log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" > "$LOG_FILE"
}

log_message "$LOG_MESSAGE"
```

*Note: `>` reads more clearly than `>>` for a stream; minor style, not a bug.*
