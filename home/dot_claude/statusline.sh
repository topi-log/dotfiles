#!/usr/bin/env bash

set -u

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -n "$cwd" ] || cwd=$PWD

directory=${cwd##*/}
[ -n "$directory" ] || directory=/

branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
if [ -n "$branch" ]; then
  printf '📁 %s  🌿 %s\n' "$directory" "$branch"
else
  printf '📁 %s\n' "$directory"
fi
