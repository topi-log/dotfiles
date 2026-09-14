#!/usr/bin/env bash
# denv の非対話部分を一時ディレクトリ上で検証する。
#
#   tests/denv.test.sh
#
# TEST_PORT を実際に LISTEN するため、ポートが空いている必要がある。
set -uo pipefail

DENV="$(cd "$(dirname "$0")/.." && pwd)/home/private_dot_config/scripts/executable_denv"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/denv-test.XXXXXX")"
TEST_PORT="${DENV_TEST_PORT:-45990}"

export DENV_CONFIG_DIR="$WORK/config"
export DENV_STATE_DIR="$WORK/state"

pass=0
fail=0

cleanup() {
	local name
	for name in $("$DENV" _names 2>/dev/null); do
		"$DENV" kill "$name" >/dev/null 2>&1
	done
	rm -rf "$WORK"
}
trap cleanup EXIT

ok() {
	pass=$((pass + 1))
	printf '  ok   %s\n' "$1"
}

ng() {
	fail=$((fail + 1))
	printf '  FAIL %s\n' "$1"
	[ $# -gt 1 ] && printf '       %s\n' "$2"
}

assert_contains() {
	case "$2" in
	*"$3"*) ok "$1" ;;
	*) ng "$1" "expected to contain '$3', got: $(printf '%s' "$2" | tr '\n' '|')" ;;
	esac
}

assert_not_contains() {
	case "$2" in
	*"$3"*) ng "$1" "expected NOT to contain '$3', got: $(printf '%s' "$2" | tr '\n' '|')" ;;
	*) ok "$1" ;;
	esac
}

assert_ok() {
	if [ "$2" -eq 0 ]; then ok "$1"; else ng "$1" "expected exit 0, got $2"; fi
}

assert_fails() {
	if [ "$2" -ne 0 ]; then ok "$1"; else ng "$1" "expected non-zero exit"; fi
}

# 起動が終わるまで待つ。状態は非同期に変わるため。
wait_for_status() {
	local name=$1 want=$2 i=0
	while [ "$i" -lt 50 ]; do
		[ "$("$DENV" _status "$name" 2>/dev/null)" = "$want" ] && return 0
		sleep 0.2
		i=$((i + 1))
	done
	return 1
}

echo "denv tests"

# --- 一覧の初期状態 -----------------------------------------------------------
out=$("$DENV" list 2>&1)
assert_contains "空の設定でも list がヘッダを出す" "$out" "NAME"

# --- 追加 ---------------------------------------------------------------------
mkdir -p "$WORK/app"
printf '%s\n' "web" "$WORK/app" "python3 -m http.server $TEST_PORT & wait" "" | "$DENV" add >/dev/null 2>&1
assert_ok "環境を追加できる" $?

out=$("$DENV" list 2>&1)
assert_contains "追加した環境が一覧に出る" "$out" "web"
assert_contains "起動前は down" "$out" "down"

# --- 入力検証 -----------------------------------------------------------------
printf '%s\n' "web" "$WORK/app" "true" "" | "$DENV" add >/dev/null 2>&1
assert_fails "同名の環境は追加できない" $?

printf '%s\n' "bad name" "$WORK/app" "true" "" | "$DENV" add >/dev/null 2>&1
assert_fails "不正な名前は拒否される" $?

printf '%s\n' "nodir" "$WORK/does-not-exist" "true" "" | "$DENV" add >/dev/null 2>&1
assert_fails "存在しないディレクトリは拒否される" $?

printf '%s\n' "nocmd" "$WORK/app" "" "" | "$DENV" add >/dev/null 2>&1
assert_fails "起動コマンドが空なら拒否される" $?

"$DENV" start no-such-env >/dev/null 2>&1
assert_fails "未登録の環境は起動できない" $?

# --- 起動 ---------------------------------------------------------------------
"$DENV" start web >/dev/null 2>&1
if wait_for_status web up; then
	ok "起動すると up になる"
else
	ng "起動すると up になる" "status=$("$DENV" _status web) log=$(cat "$WORK/state/web.log" 2>/dev/null)"
fi

out=$("$DENV" list 2>&1)
assert_contains "実際に LISTEN したポートが表示される" "$out" "$TEST_PORT"

"$DENV" start web >/dev/null 2>&1
assert_ok "起動中に start しても失敗しない" $?
assert_contains "起動中に start しても up のまま" "$("$DENV" _status web)" "up"

printf 'y\n' | "$DENV" delete web >/dev/null 2>&1
assert_fails "起動中の環境は削除できない" $?

# --- 停止 ---------------------------------------------------------------------
"$DENV" stop web >/dev/null 2>&1
if wait_for_status web down; then
	ok "停止すると down になる"
else
	ng "停止すると down になる" "status=$("$DENV" _status web)"
fi

if [ -f "$WORK/state/web.pid" ]; then
	ng "停止すると pid ファイルが消える"
else
	ok "停止すると pid ファイルが消える"
fi

out=$("$DENV" list 2>&1)
assert_not_contains "停止後はポートが表示されない" "$out" "$TEST_PORT"

# --- 停止コマンド指定 ---------------------------------------------------------
printf '%s\n' "custom" "$WORK/app" "sleep 60 & wait" \
	"touch '$WORK/stop-ran'; kill -TERM -\$(cat '$DENV_STATE_DIR/custom.pid')" |
	"$DENV" add >/dev/null 2>&1
"$DENV" start custom >/dev/null 2>&1
wait_for_status custom up || ng "停止コマンド版が起動する"
"$DENV" stop custom >/dev/null 2>&1
if wait_for_status custom down; then
	ok "停止コマンドで down になる"
else
	ng "停止コマンドで down になる" "status=$("$DENV" _status custom)"
fi
if [ -f "$WORK/stop-ran" ]; then
	ok "設定した停止コマンドが実行される"
else
	ng "設定した停止コマンドが実行される"
fi

# --- 強制終了 -----------------------------------------------------------------
"$DENV" start custom >/dev/null 2>&1
wait_for_status custom up || ng "kill 検証用に起動できる"
"$DENV" kill custom >/dev/null 2>&1
if wait_for_status custom down; then
	ok "kill で down になる"
else
	ng "kill で down になる" "status=$("$DENV" _status custom)"
fi

# --- 削除 ---------------------------------------------------------------------
printf 'y\n' | "$DENV" delete web >/dev/null 2>&1
assert_ok "停止後は削除できる" $?
assert_not_contains "削除した環境は一覧から消える" "$("$DENV" list)" "web"
if [ -f "$WORK/state/web.log" ]; then
	ng "削除するとログも消える"
else
	ok "削除するとログも消える"
fi

printf 'n\n' | "$DENV" delete custom >/dev/null 2>&1
assert_contains "確認で n を選ぶと削除されない" "$("$DENV" list)" "custom"

# --- fzf 用の内部コマンド -----------------------------------------------------
assert_contains "_detail が定義内容を出す" "$("$DENV" _detail custom 2>&1)" "$WORK/app"
"$DENV" _rows >/dev/null 2>&1
assert_ok "_rows が動く" $?
"$DENV" _detail "" >/dev/null 2>&1
assert_ok "空の名前でも内部コマンドは落ちない" $?

# --- ヘルプ -------------------------------------------------------------------
out=$("$DENV" help 2>&1)
assert_ok "help が動く" $?
assert_contains "help にサブコマンドが載る" "$out" "denv add"
assert_contains "help に一覧画面のキーが載る" "$out" "環境を追加"
assert_contains "help に設定ファイルの場所が載る" "$out" "$DENV_CONFIG_DIR/envs.json"
assert_contains "--help も同じヘルプを出す" "$("$DENV" --help 2>&1)" "使い方"

"$DENV" bogus >/dev/null 2>&1
assert_fails "未知のサブコマンドは失敗する" $?

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
