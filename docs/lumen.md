# カスタム版lumenの導入・更新

`chezmoi apply` は `install-lumen-custom` を実行し、固定したupstreamコミットに
同梱パッチを適用してネイティブバイナリをビルドします。macOSのApple Silicon/Intelで
そのPC向けにビルドします。HomebrewとCommand Line Tools、ネットワーク接続が必要です。
GitHub CLIとWezTermがなければHomebrewで導入します。ビルドが必要でRustがなければRustも導入します。
ビルド成功後にバイナリを置き換えるので、ビルド失敗時には既存バイナリを保持します。

## 操作

Claude Codeの入力待ちペインで `Cmd+Shift+R`。同じWezTermウィンドウのタブで
レビューを開きます。開始時はファイル一覧、上下移動で自動プレビューします。
Enterまたは `2` で差分へ移ると自動で行選択になり、上下で移動、Shift+上下で範囲選択、
`c` でコメントします。`s` で元のペインへ下書きを戻し、Claude CodeでEnterを押して送信します。
`?` → `p` → Spaceで常時表示するキーを選べます。

## ソース更新

編集はlumenフォークの `custom` ブランチで行います。テスト・ビルド後に
`home/private_dot_config/lumen-bootstrap/upstream.commit` の基準コミットからの差分を更新します。

```sh
LUMEN_REPO="$HOME/workspace/oss/lumen"
DOTFILES_REPO="$HOME/workspace/dotfiles"
LUMEN_BASE=$(cat "$DOTFILES_REPO/home/private_dot_config/lumen-bootstrap/upstream.commit")
git -C "$LUMEN_REPO" diff --binary "$LUMEN_BASE" HEAD -- . > "$DOTFILES_REPO/home/private_dot_config/lumen-bootstrap/custom.patch"
cp "$LUMEN_REPO/scripts/review-shortcut.sh" "$DOTFILES_REPO/home/dot_local/bin/executable_lumen-review-shortcut"
chezmoi diff
chezmoi apply
```

パッチはコミット済み変更を取り込むため、lumen側の変更を先にコミットしてください。
upstreamを更新した場合は基準コミットも変更し、新しいベースへのパッチ適用を確認してください。
run_onchangeスクリプトはパッチとインストーラのハッシュで更新を検出します。
別PCへ配布するときは、これらの変更を含むdotfilesをそのPCへ取得してください。

公式の `brew install lumen` とは別の `lumen-custom` バイナリです。
ショートカットによる利用にはClaude Codeプラグインは不要です。
