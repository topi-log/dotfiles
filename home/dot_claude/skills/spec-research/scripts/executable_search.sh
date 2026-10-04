#!/usr/bin/env bash
# プロダクトマップに登録したリポジトリの記録済みブランチを、checkout せずにまとめて git grep する。
# usage: search.sh [-i] [-a] <pattern> [repo ...] [-- pathspec ...]
#   pattern は git grep -E の正規表現。repo を省略するとマップの全リポジトリを対象にする。
#   -- の後ろは git grep の pathspec（例: -- '*.go'）。
#   -i: 大文字小文字を無視する。-a: テスト・生成コード・ドキュメントの除外をやめる。
#   SPEC_RESEARCH_MAP でマップのパスを上書きできる。SPEC_RESEARCH_MAX で1リポジトリあたりの最大行数を変えられる。
set -euo pipefail

map="${SPEC_RESEARCH_MAP:-$HOME/.claude/spec-research/products.md}"
max="${SPEC_RESEARCH_MAX:-200}"

grep_opts=(-n -I -E)
use_default_excludes=1
while [[ $# -gt 0 && "$1" == -* && "$1" != "--" ]]; do
  case "$1" in
    -i) grep_opts+=(-i) ;;
    -a) use_default_excludes=0 ;;
    *) echo "unknown option: $1（- で始まるパターンは [-]foo のように書く）" >&2; exit 2 ;;
  esac
  shift
done
if [[ $# -lt 1 ]]; then
  echo "usage: $0 [-i] [-a] <pattern> [repo ...] [-- pathspec ...]" >&2
  exit 2
fi
pattern="$1"; shift
repos=()
while [[ $# -gt 0 && "$1" != "--" ]]; do repos+=("$1"); shift; done
[[ "${1:-}" == "--" ]] && shift
pathspec=("$@")
set --
excludes=(':!*.lock' ':!*lock.json' ':!*.min.*')
if [[ $use_default_excludes -eq 1 ]]; then
  excludes+=(':!*.snap' ':!**/generated/**' ':!**/__generated__/**' ':!.claude/**' ':!docs/**'
    ':!*_test.go' ':!*.test.*' ':!*.spec.*' ':!**/__tests__/**' ':!**/testdata/**' ':!**/fixtures/**' ':!**/testfixtures/**'
    ':!**/mocks/**' ':!*_gen.go' ':!*.gen.*' ':!**/generated.go')
fi

awk -F'|' '
  /^## / { in_repos = ($0 ~ /^## リポジトリ/) ; next }
  in_repos && /^\|/ && $2 !~ /リポジトリ|---/ {
    gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $5); gsub(/^ +| +$/, "", $6)
    print $2 "\t" $5 "\t" $6
  }
' "$map" | while IFS=$'\t' read -r repo path branch; do
  if [[ ${#repos[@]} -gt 0 ]]; then
    match=0
    for want in "${repos[@]}"; do [[ "$repo" == "$want" ]] && match=1; done
    [[ $match -eq 1 ]] || continue
  fi
  path="${path/#\~/$HOME}"
  if [[ -z "$path" || ! -d "$path" ]]; then
    echo "## $repo: ローカルパスが無い" >&2
    continue
  fi
  [[ -n "$branch" ]] || branch="$(git -C "$path" symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##')"
  out="$(git -C "$path" grep "${grep_opts[@]}" -e "$pattern" "origin/${branch}" -- \
    ${pathspec[@]+"${pathspec[@]}"} "${excludes[@]}" 2>/dev/null || true)"
  [[ -n "$out" ]] || continue
  echo "## $repo (origin/${branch})"
  printf '%s\n' "$out" | sed "s#^origin/${branch}:##" | head -n "$max"
done
