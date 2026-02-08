#!/usr/bin/env bash
set -euo pipefail

echo "==> Omaterm"

# ─────────────────────────────────────────────
# Official repo packages
# ─────────────────────────────────────────────
OFFICIAL_PKGS=(
  # Base tools
  base-devel
  git
  openssh
  sudo
  less
  inetutils
  whois

  # Shell & terminal
  starship
  fzf
  eza
  zoxide
  tmux
  btop
  jq
  gum
  tldr

  # Editors & dev tools
  neovim
  luarocks
  clang
  llvm
  rust
  mise
  github-cli
  lazygit
  lazydocker
  opencode

  # Docker
  docker
  docker-buildx
  docker-compose

  # Media & image processing
  ffmpeg
  imagemagick
  libheif
  libvips
  libyaml
  openslide
  poppler-glib
  mupdf-tools
  rav1e
  svt-av1

  # Networking
  tailscale
)

# ─────────────────────────────────────────────
# Install official packages
# ─────────────────────────────────────────────
echo "==> Installing official repo packages..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}"

# ─────────────────────────────────────────────
# Install yay (AUR helper)
# ─────────────────────────────────────────────
if ! command -v yay &>/dev/null; then
  echo "==> Installing yay..."
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
fi

# ─────────────────────────────────────────────
# AUR packages (installed via yay)
# ─────────────────────────────────────────────
AUR_PKGS=(
  claude-code
)

echo "==> Installing AUR packages..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# ─────────────────────────────────────────────
# Enable systemd services
# ─────────────────────────────────────────────
echo "==> Enabling services..."
sudo systemctl enable --now docker.service
sudo systemctl enable --now sshd.service
sudo systemctl enable --now tailscaled.service

# Add user to docker group
if ! groups | grep -q docker; then
  sudo usermod -aG docker "$USER"
  echo "    Added $USER to docker group (re-login to take effect)"
fi

# ─────────────────────────────────────────────
# Git config
# ─────────────────────────────────────────────
echo "==> Writing ~/.gitconfig..."
cat >"$HOME/.gitconfig" <<'GITCONFIG'
[credential "https://github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential
[credential "https://gist.github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential

[alias]
	co = checkout
	br = branch
	ci = commit
	st = status
[init]
	defaultBranch = master
[pull]
	rebase = true 			 # Rebase (instead of merge) on pull
[push]
	autoSetupRemote = true   # Automatically set upstream branch on push
[diff]
	algorithm = histogram    # Clearer diffs on moved/edited lines
	colorMoved = plain       # Highlight moved blocks in diffs
	mnemonicPrefix = true    # More intuitive refs in diff output
[commit]
	verbose = true           # Include diff comment in commit message template
[column]
	ui = auto 			     # Output in columns when possible
[branch]
	sort = -committerdate    # Sort branches by most recent commit first
[tag]
	sort = -version:refname  # Sort version numbers as you would expect
[rerere]
	enabled = true           # Record and reuse conflict resolutions
	autoupdate = true        # Apply stored conflict resolutions automatically
GITCONFIG

# ─────────────────────────────────────────────
# Shell config
# ─────────────────────────────────────────────
echo "==> Writing ~/.bashrc..."
cat >"$HOME/.bashrc" <<'BASHRC'
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export EDITOR="nvim"
export PATH="$PATH:./bin"

# File system
alias ls='eza -lh --group-directories-first --icons=auto'
alias lsa='ls -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'

alias ff="fzf --preview 'bat --style=numbers --color=always {}'"

alias cd="zd"
zd() {
  if [ $# -eq 0 ]; then
    builtin cd ~ && return
  elif [ -d "$1" ]; then
    builtin cd "$1"
  else
    z "$@" && printf "\U000F17A9 " && pwd || echo "Error: Directory not found"
  fi
}

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
alias c='opencode'
alias cx='claude'
alias d='docker'
alias r='rails'
n() { if [ "$#" -eq 0 ]; then nvim .; else nvim "$@"; fi; }

# Git
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# Other
alias c="opencode"
alias cc="claude --permission-mode=plan --allow-dangerously-skip-permissions"

# Init
if command -v mise &>/dev/null; then
  eval "$(mise activate bash)"
fi

if command -v starship &>/dev/null; then
  # clear stale readline state before rendering prompt (prevents artifacts in prompt after abnormal exits like SIGQUIT)
  __sanitize_prompt() { printf '\r\033[K'; }
  PROMPT_COMMAND="__sanitize_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
  eval "$(starship init bash)"
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
fi
BASHRC

echo "==> Writing ~/.bash_profile..."
cat >"$HOME/.bash_profile" <<'BASHPROFILE'
[[ -f ~/.bashrc ]] && . ~/.bashrc
BASHPROFILE

# ─────────────────────────────────────────────
# Starship prompt config
# ─────────────────────────────────────────────
echo "==> Writing starship config..."
mkdir -p "$HOME/.config"
cat >"$HOME/.config/starship.toml" <<'STARSHIP'
add_newline = true
command_timeout = 200
format = "[$directory$git_branch$git_status]($style)$character"

[character]
error_symbol = "[✗](bold cyan)"
success_symbol = "[❯](bold cyan)"

[directory]
truncation_length = 2
truncation_symbol = "…/"
repo_root_style = "bold cyan"
repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "

[git_branch]
format = "[$branch]($style) "
style = "italic cyan"

[git_status]
format     = '[$all_status]($style)'
style      = "cyan"
ahead      = "⇡${count} "
diverged   = "⇕⇡${ahead_count}⇣${behind_count} "
behind     = "⇣${count} "
conflicted = " "
up_to_date = " "
untracked  = "? "
modified   = " "
stashed    = ""
staged     = ""
renamed    = ""
deleted    = ""
STARSHIP

# ─────────────────────────────────────────────
# mise config
# ─────────────────────────────────────────────
echo "==> Writing mise config..."
mkdir -p "$HOME/.config/mise"
cat >"$HOME/.config/mise/config.toml" <<'MISE'
[settings]
experimental = true
idiomatic_version_file_enable_tools = ["ruby"]
MISE

# ─────────────────────────────────────────────
# Neovim config (LazyVim)
# ─────────────────────────────────────────────
echo "==> Writing neovim config..."

# ─────────────────────────────────────────────
# Post-install steps
# ─────────────────────────────────────────────
echo ""
echo "==> Setup complete! Manual steps remaining:"
echo "    1. Set git config --global user.name 'Your name'"
echo "    2. Set git config --global user.email 'Your email'"
echo "    3. Run 'gh auth login' to authenticate GitHub CLI"
echo "    4. Re-login for docker group membership to take effect"
