#!/usr/bin/env bash
# Debounced notification sound for Claude Code.
#
# Wired to the PermissionRequest / Notification / Stop hooks. Each call bumps a
# per-session marker and schedules a check DEBOUNCE_SEC later; the sound plays
# only if no further hook fired in the meantime. A burst of permission prompts
# and intermediate stops therefore collapses into a single beep at the point
# Claude actually hands control back and stays quiet.
#
# Tunables (environment):
#   CLAUDE_NOTIFY_SOUND     path to an audio file (default: Glass.aiff)
#   CLAUDE_NOTIFY_DEBOUNCE  seconds of quiet required before beeping (default: 4)
set -uo pipefail

SOUND="${CLAUDE_NOTIFY_SOUND:-/System/Library/Sounds/Glass.aiff}"
DEBOUNCE_SEC="${CLAUDE_NOTIFY_DEBOUNCE:-4}"
STATE_DIR="${TMPDIR:-/tmp}/claude-notify"

payload=$(cat 2>/dev/null || true)
session=$(printf '%s' "$payload" \
	| sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
	| head -1)
[ -n "$session" ] || session="default"

mkdir -p "$STATE_DIR" 2>/dev/null || true
marker="$STATE_DIR/$session"
token="$$-${RANDOM}-$(date +%s)"
printf '%s' "$token" >"$marker" 2>/dev/null || exit 0

# Detach so the beep survives this hook returning. A later hook overwrites the
# marker, so this subshell finds a mismatch and stays silent — last one wins.
nohup bash -c '
	sleep "$1"
	[ "$(cat "$2" 2>/dev/null)" = "$3" ] || exit 0
	rm -f "$2"
	exec afplay "$4"
' _ "$DEBOUNCE_SEC" "$marker" "$token" "$SOUND" >/dev/null 2>&1 &

exit 0
