# denv — 開発環境の起動管理

ローカルで動かす開発環境（ディレクトリ + 起動コマンド）を登録しておき、
一覧で起動状況とポートを確認しながら起動・停止できるツール。

`jq` / `lsof` / `fzf` を使う。`fzf` が無い場合はサブコマンドだけ使える。

```sh
brew install jq fzf
```

PATH に `~/.config/scripts` が入っていれば `denv` で起動する。

## 使い方

引数なしで実行すると一覧が開く。

```
NAME               PORT           STATUS  DIR
web-app            3000           ● up    ~/workspace/web-app
api                8080,35729     ● up    ~/workspace/api
admin              -              ○ down  ~/workspace/admin
```

| キー | 動作 |
|---|---|
| `enter` | 起動中なら停止、停止中なら起動 |
| `s` / `x` | 起動 / 停止 |
| `k` | 強制終了（SIGKILL） |
| `l` | ログを追従表示（`q` で戻る） |
| `a` / `e` / `d` | 追加 / 編集 / 削除 |
| `r` / `q` | 再描画 / 終了 |
| `?` | ヘルプ（`q` で戻る） |

右ペインに定義内容とログの末尾が出る。

同じ操作はサブコマンドでもできる。

```sh
denv list            # 一覧を一度だけ表示
denv start web-app
denv stop web-app
denv kill web-app
denv log web-app
denv add             # 対話で登録
denv edit web-app
denv delete web-app
denv help            # 使い方とキー一覧
```

## 環境の登録

`a` または `denv add` で `name` → `dir` → `start` → `stop` を順に聞かれる。
`dir` は既定でカレントディレクトリ。`stop` は空でよい。

定義は `~/.config/denv/envs.json` に入る。マシン固有のパスを含むため
chezmoi の管理対象外。

```json
{
  "envs": [
    { "name": "web-app", "dir": "~/workspace/web-app", "start": "npm run dev", "stop": "" }
  ]
}
```

## 起動と停止の仕組み

起動コマンドは専用のプロセスグループでバックグラウンド実行され、出力は
`~/.local/state/denv/<name>.log` に追記される。ターミナルを閉じても動き続ける。

停止は `stop` コマンドがあればそれを実行し、無ければプロセスグループに
SIGTERM を送って 5 秒待ち、残っていれば SIGKILL する。グループ単位で送るため、
`npm run dev` のように子プロセスを持つ起動コマンドでも取り残しが出ない。

`docker compose up` のように「起動コマンドが終了しても実体は残る」ものは、
`stop` に `docker compose down` を設定する。

## ポート

ポートは登録しない。一覧を描画するたびに、そのプロセスグループが実際に
LISTEN しているポートを `lsof` で読み直して表示する。アプリ側がポートを
変えても追従する。複数あればカンマ区切り、無ければ `-`。

denv 以外から起動したプロセスは検知しない（照合する手がかりが無いため）。

## 状態ファイル

| パス | 内容 |
|---|---|
| `~/.config/denv/envs.json` | 環境定義 |
| `~/.local/state/denv/<name>.pid` | プロセスグループ ID |
| `~/.local/state/denv/<name>.log` | 起動コマンドの出力 |

環境を削除すると pid とログも消える。

## テスト

```sh
tests/denv.test.sh
```

一時ディレクトリ上で起動・停止・削除を一通り試す。実際にポート 45990 を
LISTEN するため、空いている必要がある（`DENV_TEST_PORT` で変更できる）。
