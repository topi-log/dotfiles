# WezTerm Config

WezTerm terminal configuration for macOS.

## Overview

- **Font**: HackGen Console (15pt)
- **Color Scheme**: Ef-Night
- **Translucent Background**: opacity 0.8 + blur 20
- **Tab Bar**: Minimal style (matches color scheme)
- **IME**: Enabled
- **Default cwd**: `~/workspace`

### Key Bindings

| Key | Action |
|---|---|
| `Cmd+/` | Show the shortcut list |
| `Cmd+Shift+Space` | Open the current directory in Visual Studio Code |
| `Cmd+;` | List Claude Code sessions; pick one to jump to its pane |
| `Cmd+W` | Close pane |
| `Cmd+,` | Split vertically |
| `Cmd+.` | Split horizontally |
| `Shift+Enter` | Send a newline |

### Mouse Selection

Plain left-drag selects and copies even while the running program has mouse
reporting enabled, as long as it is on the primary screen (Claude Code, shell).
Alt-screen apps (nvim, lazygit, fzf) keep receiving mouse events as before.

## Setup

### 1. Install WezTerm and the font

```bash
brew install --cask wezterm
brew install --cask font-hackgen
```

### 2. Deploy the config

The config is managed by chezmoi in this repository. See the root
[README](../README.md) for setup. `chezmoi apply` creates
`~/.config/wezterm/wezterm.lua` as a symlink into this repository.

## wlay - Overlay Pane Command

A shell script that opens a temporary full-screen pane by combining
`split-pane` and `zoom-pane`. It closes when the program exits, restoring the
original pane.

### Usage

| Command | Action |
|---|---|
| `wlay` / `wlay sh` | Open zsh |
| `wlay git` | Open lazygit |

Any argument other than the subcommands (`sh`, `git`) is executed as-is
(e.g. `wlay htop`).

### Setup

`chezmoi apply` creates `~/.config/scripts/wlay` as a symlink to
`~/.config/wezterm/wlay`. Add the directory to PATH in `~/.zshrc` by hand
(`~/.zshrc` is not managed by this repository).

```bash
export PATH="$HOME/.config/scripts:$PATH"
```

## cst - Claude Code Session Status

Lists every running Claude Code session: state, directory and branch, elapsed
time since the last event, the tool it is executing, and (on the second line)
the last prompt. Long values are cut to the terminal width.

```
  状態      場所                          経過   ツール / プロンプト
* 作業中    dotfiles (main)               3s     Bash: Run tests
            hooks を追加してセッション一覧を出せるようにしたい
  許可待ち  crm-lp (feat/header-redesign)  2m     Edit
            LP のヘッダーをリニューアルして
  入力待ち  sub1 (main)                   15m
```

`*` marks the pane the command was run from.

| Command | Action |
|---|---|
| `cst` | Print the table once |
| `cst -w` | Redraw every 2 seconds, `q` to quit (`wlay cst -w` opens it in an overlay pane) |
| `cst --json` | One JSON object per session per line (used by `Cmd+;`) |
| `Cmd+;` | Same list as a WezTerm overlay; Enter jumps to that session's pane |

### How it works

Claude Code hooks (SessionStart / UserPromptSubmit / PreToolUse / PostToolUse /
PermissionRequest / Stop / SessionEnd) run `~/.claude/hooks/session-status.sh`,
which writes one JSON file per session to `~/.claude/sessions-status/`. The
hook inherits `WEZTERM_PANE` from Claude Code, which is how a session is tied to
its pane. `cst` reads those files and removes entries whose pane no longer
exists or that have not been updated for 24 hours.

Only sessions started after the hooks were installed appear. Sessions started
outside WezTerm (VS Code extension, etc.) are listed without a pane and cannot
be jumped to.

### Setup

Requires `jq`. `chezmoi apply` installs the hook, the `cst` script and the
hook registrations in `~/.claude/settings.json`. Restart running Claude Code
sessions so they pick up the new hooks.

## Credits

This config is based on [fs0414/weztermdot](https://github.com/fs0414/weztermdot)
by another author. It was cloned to `~/.config/wezterm`, modified locally
(default cwd, font size, opacity, mouse selection bindings), and brought into
this dotfiles repository on 2026-09-04. The upstream repository is untouched.
