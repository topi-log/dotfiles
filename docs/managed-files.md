# 管理対象ファイル

chezmoi が配置するファイルと、あえて管理していないファイルの一覧。
実際に配置されているものは `chezmoi managed` でも確認できる。

## 管理対象

| 実配置パス | 配置方式 |
|---|---|
| `~/.config/wezterm/wezterm.lua` | symlink |
| `~/.config/wezterm/wlay` | 実ファイル（実行可能） |
| `~/.config/scripts/wlay` | symlink（`wezterm/wlay` を指す） |
| `~/.config/scripts/cst` | 実ファイル（実行可能） |
| `~/.config/scripts/denv` | 実ファイル（実行可能） |
| `~/.local/bin/lumen-custom` | apply 時にビルド（chezmoi の配置対象ではない） |
| `~/.local/bin/lumen-review-shortcut` | 実ファイル（実行可能） |
| `~/.config/scripts/install-lumen-custom` | 実ファイル（実行可能） |
| `~/.config/lumen-bootstrap/` | 固定バージョン・カスタマイズ差分・ライセンス |
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

## apply 時に走るスクリプト

`home/.chezmoiscripts/` に置いてある。配置されるファイルではなく、
`chezmoi apply` のたびに実行される。

| スクリプト | 実行タイミング |
|---|---|
| `run_after_install-fonts.sh` | 毎回。HackGen Console が無ければ導入するか聞く |
| `run_onchange_after_install-lumen-custom.sh.tmpl` | lumen のパッチ・インストーラ・ショートカットのいずれかが変わったとき |

## symlink にならないファイル

次のファイルは chezmoi の仕様により実ファイルとして書き出される。
編集はリポジトリ側で行い、`chezmoi apply` で配置する向きになる。

| ファイル | 実ファイルになる理由 |
|---|---|
| `~/.claude/settings.json` | テンプレート（マシン固有の値を含む） |
| `~/.config/wezterm/wlay` | 実行可能属性が必要 |
| `~/.config/scripts/cst` | 実行可能属性が必要 |
| `~/.config/scripts/denv` | 実行可能属性が必要 |
| `~/.config/scripts/install-lumen-custom` | 実行可能属性が必要 |
| `~/.local/bin/lumen-review-shortcut` | 実行可能属性が必要 |

`chezmoi managed --include=files` で実ファイルだけを一覧できる。

`~/.claude/settings.json` は Claude Code 自身が書き換えるため、
差分の扱いに注意が必要。[README の該当節](../README.md#settingsjson-だけ編集の向きが逆)を参照。

## 管理していないもの

- `~/.config/gh/hosts.yml` — 認証トークンを含む
- `~/.config/karabiner/automatic_backups/` — Karabiner-Elements の自動生成物
- `~/.config/karabiner/assets/complex_modifications/1737014820.json` —
  外部からインポートしたルールセット。出自とライセンスが不明なため再配布しない
- `~/.zsh/`（`git-completion.bash`、`git-prompt.sh`、`_git`）— git 公式の
  スクリプトで GPL-2.0。再配布を避けるため管理対象外。取得方法は
  [README](../README.md#git-の補完スクリプト) を参照
- `~/.config/git/ignore` — 未着手。`chezmoi add` で追加できる
