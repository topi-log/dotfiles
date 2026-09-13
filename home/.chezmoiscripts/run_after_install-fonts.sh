#!/bin/sh

set -eu

case ":$PATH:" in
  *:/opt/homebrew/bin:*) ;;
  *) PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" ;;
esac

font_installed() {
  for dir in "$HOME/Library/Fonts" /Library/Fonts; do
    for path in "$dir"/HackGenConsole*; do
      if [ -e "$path" ]; then
        return 0
      fi
    done
  done
  return 1
}

if font_installed; then
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "fonts: HackGen Console がありません。Homebrew がないため手動でインストールしてください" >&2
  exit 0
fi

# chezmoi はスクリプトの stdin を端末につながないため、直接 /dev/tty を開く。
if ! { : < /dev/tty; } 2>/dev/null; then
  echo "fonts: HackGen Console がありません。WezTerm はフォールバックフォントで表示されます (brew install --cask font-hackgen)" >&2
  exit 0
fi

printf 'fonts: HackGen Console がありません。brew install --cask font-hackgen でインストールしますか? [y/N] ' > /dev/tty
read -r answer < /dev/tty || answer=""

case "$answer" in
  [yY] | [yY][eE][sS]) brew install --cask font-hackgen ;;
  *) echo "fonts: インストールをスキップしました" >&2 ;;
esac
