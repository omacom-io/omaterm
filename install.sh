#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Common functions for Omaterm installation
show_banner() {
  clear
  echo
  echo " ▄██████▄    ▄▄▄▄███▄▄▄▄      ▄████████     ███        ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄  
███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄
███    ███ ███   ███   ███   ███    ███    ▀███▀▀██   ███    █▀    ███    ███ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███   ▀  ▄███▄▄▄      ▄███▄▄▄▄██▀ ███   ███   ███
███    ███ ███   ███   ███ ▀███████████     ███     ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    █▄  ▀███████████ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    ███   ███    ███ ███   ███   ███
 ▀██████▀   ▀█   ███   █▀    ███    █▀     ▄████▀     ██████████   ███    ███  ▀█   ███   █▀ 
                                                                    ███    ███                "
}

section() {
  echo -e "\n==> $1"
}

install_omadots() {
  curl -fsSL https://raw.githubusercontent.com/omacom-io/omadots/refs/heads/master/install.sh | bash
}

install_configs() {
  local installer_dir="$1"

  section "Installing configs..."
  mkdir -p "$HOME/.config"
  cp -Rf "$installer_dir/config/"* "$HOME/.config/"
  echo "✓ Neovim"
  echo "✓ Starship"

  if ! grep -q "if \[\[ -z \$TMUX \]\]" "$HOME/.bashrc" 2>/dev/null; then
    cat >>"$HOME/.bashrc" <<'EOF'
if [[ -z $TMUX ]]; then
  t
fi
EOF
    echo "✓ Tmux auto-start"
  fi
}

install_bins() {
  local installer_dir="$1"

  section "Installing bins..."
  mkdir -p "$HOME/.local/bin"
  cp -Rf "$installer_dir/bin/"* "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/"*
  echo "✓ omaterm-ssh"
  echo "✓ omaterm-theme"
  echo "✓ omaterm-refresh"
}

install_mise_tools() {
  section "Installing Ruby + Node..."
  eval "$(mise activate bash)" 2>/dev/null || true
  mise use -g node
  mise use -g ruby
  export PATH="$HOME/.local/share/mise/shims:$PATH"
}

setup_docker_group() {
  if ! groups | grep -q docker; then
    if command -v usermod &>/dev/null; then
      sudo usermod -aG docker "$USER"
    else
      sudo adduser "$USER" docker
    fi
  fi
}

interactive_setup() {
  section "Interactive setup..."

  if ! gh auth status &>/dev/null; then
    echo
    if gum confirm "Authenticate with GitHub?" </dev/tty; then
      gh auth login
    fi
  fi

  if ! tailscale status &>/dev/null; then
    echo
    if gum confirm "Connect to Tailscale network?" </dev/tty; then
      echo "This might take a minute..."
      sudo systemctl enable --now tailscaled.service
      sudo tailscale up --ssh --accept-routes
    fi
  fi
}

finish() {
  section "Finished!"
  echo "Now logout and back in for everything to take effect"
}

run_installation() {
  show_banner

  # OS-specific package installation
  install_packages

  # Omadots
  install_omadots

  # Configs and bins
  local repo="https://github.com/omacom-io/omaterm.git"
  local installer_dir="$(mktemp -d)"
  trap 'rm -rf "$installer_dir"' EXIT

  section "Cloning Omaterm..."
  git clone --depth 1 "$repo" "$installer_dir"

  install_configs "$installer_dir"
  install_bins "$installer_dir"

  # Mise tooling
  install_mise_tools

  # OS-specific tools that need npm (installed after mise provides node)
  install_npm_tools

  # OS-specific service enabling
  enable_services

  # Setup Docker group
  setup_docker_group

  # Interactive setup
  interactive_setup

  # Done!
  finish
}

# OS detection and dispatch
if [ -f /etc/arch-release ]; then
  source "$SCRIPT_DIR/install-arch.sh"
elif [ -f /etc/debian_version ] && grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
  source "$SCRIPT_DIR/install-ubuntu.sh"
else
  echo "Error: Unsupported operating system"
  echo "Omaterm supports Arch Linux and Ubuntu 24.04 LTS+"
  exit 1
fi

run_installation
