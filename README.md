# dotfiles

macOS の設定ファイルを [chezmoi](https://www.chezmoi.io/) の symlink モードで
管理するリポジトリ。

## 仕組み

実配置先（`~/.config/wezterm/wezterm.lua` など）がこのリポジトリ内のファイルへの
シンボリックリンクになる。実ファイルを編集すればリポジトリが即座に更新されるため、
変更を「取り込む」操作は不要。

ただし次のファイルは chezmoi の仕様により実ファイルとして書き出されるため、
リポジトリ側を編集して `chezmoi apply` する向きで運用する。

| ファイル | 実ファイルになる理由 |
|---|---|
| `~/.claude/settings.json` | テンプレート（マシン固有の値を含む） |
| `~/.config/wezterm/wlay` | 実行可能属性が必要 |
| `~/.config/scripts/cst` | 実行可能属性が必要 |

## 管理対象

| 実配置パス | 配置方式 |
|---|---|
| `~/.config/wezterm/wezterm.lua` | symlink |
| `~/.config/wezterm/wlay` | 実ファイル（実行可能） |
| `~/.config/scripts/wlay` | symlink（`wezterm/wlay` を指す） |
| `~/.config/scripts/cst` | 実ファイル（実行可能） |
| `~/.config/scripts/creview` | 実ファイル（実行可能） |
| `~/.config/scripts/creview-code` | 実ファイル（実行可能） |
| `~/.vscode/extensions/topilog.claude-review-0.1.0/` | VS Codeレビュー拡張 |
| `~/.config/karabiner/karabiner.json` | symlink |
| `~/.config/karabiner/assets/complex_modifications/windows_keys.json` | symlink |
| `~/.config/gh/config.yml` | symlink |
| `~/.gitconfig` | symlink |
| `~/.zprofile` | symlink |
| `~/.zshrc` | symlink |
| `~/.claude/settings.json` | 実ファイル（テンプレート） |
| `~/.claude/CLAUDE.md` | symlink |
| `~/.claude/hooks/notify-when-quiet.sh` | symlink |
| `~/.claude/hooks/session-status.sh` | symlink |
| `~/.claude/statusline.sh` | symlink |

管理していないもの:

- `~/.config/gh/hosts.yml` — 認証トークンを含む
- `~/.config/karabiner/automatic_backups/` — Karabiner-Elements の自動生成物
- `~/.config/karabiner/assets/complex_modifications/1737014820.json` —
  外部からインポートしたルールセット。出自とライセンスが不明なため再配布しない
- `~/.zsh/`（`git-completion.bash`、`git-prompt.sh`、`_git`）— git 公式の
  スクリプトで GPL-2.0。再配布を避けるため管理対象外。取得方法は後述
- `~/.config/git/ignore` — 未着手。`chezmoi add` で追加できる

## セットアップ（新マシン）

```sh
brew install chezmoi jq pygments
git clone git@github.com:topi-log/dotfiles.git ~/workspace/dotfiles
```

`~/.config/chezmoi/chezmoi.toml` を手で作る。**`chezmoi init` は使わない**
（後述）。

```sh
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'TOML'
mode = "symlink"
sourceDir = "~/workspace/dotfiles"

[data]
    # Claude Code で有効にするプラグイン
    claudePlugins = { "ruby-lsp@claude-plugins-official" = true }

    # Claude Code の追加マーケットプレイス
    claudeMarketplaces = {}
TOML
```

公開したくない設定（社内マーケットプレイスなど）はこの `[data]` に書く。
このファイルは chezmoi の管理対象外なのでリポジトリには入らない。

配置する。

```sh
chezmoi diff                 # 何が変わるか必ず確認する
chezmoi apply
```

`wlay` を使うには PATH に `~/.config/scripts` を追加する。
リポジトリ側の `home/dot_zshrc` を編集して `chezmoi apply` する。

```sh
export PATH="$HOME/.config/scripts:$PATH"
```

### chezmoi init を使わない理由

`chezmoi init` は source 内の `.chezmoi.toml.tmpl` から
`~/.config/chezmoi/chezmoi.toml` を **上書き生成** する。このリポジトリは
public なので `[data]` の実際の値をテンプレートに書けず、init を実行すると
手で入れた設定が失われる。そのため設定テンプレートを置かず、config は
手管理にしている。

## 日常の操作

| やりたいこと | コマンド |
|---|---|
| 配置する | `chezmoi apply` |
| 配置前に差分を見る | `chezmoi diff` |
| 新しいファイルを管理下に入れる | `chezmoi add ~/.config/foo` |
| 実ファイルの変更を取り込む | `chezmoi re-add <path>`（テンプレートには使えない） |
| リポジトリ側を編集する | `chezmoi edit <path>` |
| 管理下のファイルを一覧する | `chezmoi managed` |

symlink で管理しているファイルは、実ファイルを編集すればそのまま
リポジトリへの編集になる。`git diff` で確認してコミットする。

### settings.json だけ編集の向きが逆

`~/.claude/settings.json` はテンプレートなので symlink にならない。
Claude Code が `/model` や `/config` でこのファイルを書き換えると、
リポジトリとの差分が生まれる。`chezmoi diff` で気づけるので、変更を
リポジトリ側に写して `chezmoi apply` する。

```sh
chezmoi diff                              # 差分を確認
chezmoi edit ~/.claude/settings.json      # ソースの .tmpl を開く
chezmoi apply
```

`chezmoi re-add` はテンプレートには使えない（chezmoi の仕様）。

## シェル設定の役割分担

zsh は読み込むタイミングが違う設定ファイルを持つ。役割を混ぜると設定同士が
衝突するため、次のように分けている。

| ファイル | 読まれるタイミング | 置くもの |
|---|---|---|
| `~/.zprofile` | ログインシェルで 1 回 | 環境変数と PATH |
| `~/.zshrc` | 対話シェルを開くたび | エイリアス、プロンプト、補完、シェル関数 |

環境変数は `export` すれば子プロセスに継承されるので `.zprofile` で一度
設定すれば足りる。一方でエイリアスやプロンプトは継承されないため、対話シェル
ごとに `.zshrc` で設定し直す必要がある。

macOS の端末（Terminal.app、iTerm、wezterm）は既定でログインシェルとして
起動するため両方が読まれる。そのためどちらに書いても動いてしまうが、
VS Code の統合ターミナルのような非ログイン対話シェルでは `.zshrc` だけが
読まれるので、この分担を守らないと環境によって挙動が変わる。

マシンごとに導入状況が違うツール（nodenv、rbenv、PostgreSQL、Flutter、Go、
VS Code）は存在チェックを通してから設定する。入っていないマシンでは黙って
スキップされるので、同じ設定ファイルをどのマシンでも使える。

### git の補完スクリプト

`.zshrc` は `~/.zsh/git-completion.bash` があれば git の補完に使う。この
ファイルは git 公式のもので GPL-2.0 なので、このリポジトリでは配布していない。
必要なら取得する（なくても補完以外は動く）。

```sh
mkdir -p ~/.zsh
curl -o ~/.zsh/git-completion.bash \
  https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
curl -o ~/.zsh/_git \
  https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh
```

プロンプトの git ブランチ表示は zsh 組み込みの `vcs_info` を使っているため、
外部スクリプト（`git-prompt.sh`）は不要。

## ディレクトリのパーミッション

`~/.config` と `~/.config/karabiner` 配下は 0700。chezmoi のディレクトリの
既定は 0755 なので、そのままでは apply でパーミッションが緩む。これを防ぐため
source 側のディレクトリに `private_` 接頭辞をつけている
（`private_dot_config`、`private_karabiner` など）。

## 注意

**`~/workspace` を移動・整理すると全ての symlink が切れる。**
source directory がこのリポジトリの場所を指しているため。切れた場合は
`~/.config/chezmoi/chezmoi.toml` の `sourceDir` を新しいパスに書き換えて
`chezmoi apply` を再実行する。

## ドキュメント

- [wezterm の設定と wlay / cst](docs/wezterm.md)
- [Claude Code グローバル指示の日本語訳](docs/claude-global-instructions.ja.md)
