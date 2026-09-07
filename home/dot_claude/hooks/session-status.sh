#!/usr/bin/env bash
# Records what each Claude Code session is doing so `cst` can list them.
#
# Wired to SessionStart / UserPromptSubmit / PreToolUse / PostToolUse /
# PermissionRequest / Stop / SessionEnd. Writes one JSON file per session to
# STATUS_DIR. Must stay synchronous: an async PostToolUse could land before its
# PreToolUse and leave a stale tool name behind.
set -uo pipefail

STATUS_DIR="${CLAUDE_SESSION_STATUS_DIR:-$HOME/.claude/sessions-status}"

payload=$(cat 2>/dev/null) || exit 0
command -v jq >/dev/null 2>&1 || exit 0

session=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$session" ] || exit 0
event=$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null)
file="$STATUS_DIR/$session.json"

if [ "$event" = "SessionEnd" ]; then
	rm -f "$file"
	exit 0
fi

mkdir -p "$STATUS_DIR" 2>/dev/null || exit 0

existing='{}'
if [ -r "$file" ]; then
	existing=$(cat "$file" 2>/dev/null)
	printf '%s' "$existing" | jq -e . >/dev/null 2>&1 || existing='{}'
fi

tmp=$(mktemp "$STATUS_DIR/.$session.XXXXXX" 2>/dev/null) || exit 0

jq -n \
	--argjson existing "$existing" \
	--argjson payload "$payload" \
	--arg event "$event" \
	--arg pane "${WEZTERM_PANE:-}" \
	--argjson now "$(date +%s)" '
  def tool_label:
    if .tool_name == "Bash" and ((.tool_input.description // "") != "")
    then "Bash: " + .tool_input.description
    else (.tool_name // "") end;

  ({state: "idle", prompt: "", tool: ""} + $existing + {
    session_id: $payload.session_id,
    cwd: ($payload.cwd // $existing.cwd // ""),
    pane_id: (if $pane == "" then ($existing.pane_id // null) else ($pane | tonumber) end),
    updated_at: $now
  }) as $base
  | if $event == "SessionStart" then
      $base + {state: "idle", tool: ""}
    elif $event == "UserPromptSubmit" then
      # Prompts starting with "<" are injected by the harness (task
      # notifications, bash-input echoes), not typed by the user: keep the
      # previous prompt so the list keeps showing the actual task.
      (($payload.prompt // "") | gsub("\\s+"; " ")) as $p
      | $base + {state: "busy", tool: "",
                 prompt: (if ($p | startswith("<")) then $base.prompt else $p[:200] end)}
    elif $event == "PreToolUse" then
      $base + {state: "busy", tool: ($payload | tool_label)}
    elif $event == "PostToolUse" then
      $base + {state: "busy", tool: ""}
    elif $event == "PermissionRequest" then
      $base + {state: "waiting",
               tool: (($payload | tool_label) as $t | if $t == "" then $base.tool else $t end)}
    elif $event == "Stop" then
      $base + {state: "idle", tool: ""}
    else $base end
' >"$tmp" 2>/dev/null && mv -f "$tmp" "$file" 2>/dev/null

rm -f "$tmp" 2>/dev/null
exit 0
