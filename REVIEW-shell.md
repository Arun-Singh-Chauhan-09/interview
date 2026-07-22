# Review — `shell/script.sh`

## Summary

The script intends to log a timestamped message to stdout. As written it does
not work: the log function writes to an undefined variable, and most of the
message is silently discarded. Four issues below, in severity order.

## Issues

### 1. Undefined variable — the script's core bug

```bash
LOG_FILE='$STDOUT'          # defines LOG_FILE
echo "..." >> "$LOGFILE"    # writes to LOGFILE — different variable
```

`LOG_FILE` and `LOGFILE` are not the same variable. `$LOGFILE` is never
assigned, so it expands to an empty string and the redirect becomes
`>> ""`, which fails with an ambiguous-redirect error.

**Fix:** use one consistent name.

### 2. Single quotes prevent variable expansion

```bash
LOG_FILE='$STDOUT'
```

Single quotes are literal in bash, so `LOG_FILE` holds the seven characters
`$STDOUT` rather than the value `/dev/stdout`. Even with issue 1 fixed, the
script would try to append to a file literally named `$STDOUT`.

**Fix:** double quotes — `LOG_FILE="$STDOUT"`.

### 3. Unquoted argument causes word splitting

```bash
log_message $LOG_MESSAGE
```

Unquoted, bash splits the value on whitespace and passes each word as a
separate argument. `$1` receives only `is`; the rest of the message is
dropped. This fails silently, which makes it the most dangerous of the four.

**Fix:** `log_message "$LOG_MESSAGE"`.

### 4. Missing shebang and error handling

The script has no `#!/usr/bin/env bash` line, so its interpreter depends on
how it is invoked, and no `set -euo pipefail`, so failures pass unnoticed.

## Corrected script

```bash
#!/usr/bin/env bash
set -euo pipefail

STDOUT="/dev/stdout"
LOG_FILE="$STDOUT"
LOG_MESSAGE="is the date, should log to $STDOUT"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "$LOG_MESSAGE"
```

## Note on `>>` vs `>`

Appending to `/dev/stdout` works, but `>>` implies a file that accumulates.
For a stream, `>` reads more clearly. Minor style point, not a bug.
