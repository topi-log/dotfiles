# WezTerm Config

WezTerm terminal configuration for macOS.

## Overview

- **Font**: Hack Nerd Font (15pt)
- **Color Scheme**: Ef-Night
- **Translucent Background**: opacity 0.8 + blur 20
- **Tab Bar**: Minimal style (matches color scheme)
- **IME**: Enabled
- **Default cwd**: `~/workspace`

### Key Bindings

| Key | Action |
|---|---|
| `Cmd+Shift+Space` | Open the current directory in Visual Studio Code |
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
brew install --cask font-hack-nerd-font
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

## Credits

This config is based on [fs0414/weztermdot](https://github.com/fs0414/weztermdot)
by another author. It was cloned to `~/.config/wezterm`, modified locally
(default cwd, font size, opacity, mouse selection bindings), and brought into
this dotfiles repository on 2026-09-04. The upstream repository is untouched.
