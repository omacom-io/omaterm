#!/usr/bin/env bash
set -euo pipefail

banner() {
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
  echo -e "\n==> Installing Omaterm..."
}

section() {
  echo -e "\n==> $1"
}

is_arch() {
  [ -f /etc/arch-release ]
}

is_debian() {
  [ -f /etc/debian_version ]
}

is_fedora() {
  [ -f /etc/fedora-release ]
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

install_docker_packages() {
  if is_wsl; then
    if docker info >/dev/null 2>&1; then
      return
    fi

    echo "Error: Docker is not available."
    echo "Install and start Docker Desktop for Windows with WSL integration enabled, then re-run this installer."
    exit 1
  elif command -v docker &>/dev/null && systemctl cat docker.service &>/dev/null; then
    return
  fi

  if is_arch; then
    section "Installing Docker..."
    sudo pacman -S --needed --noconfirm docker
  elif is_debian; then
    section "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io
  elif is_fedora; then
    section "Installing Docker..."
    sudo dnf install -y moby-engine
  else
    echo "Error: This OS is not supported by the installer."
    echo "Install Docker manually, then run this installer again."
    exit 1
  fi
}

ensure_local_bin_on_path() {
  local shell_rc="$HOME/.bashrc"
  local path_line='export PATH="$HOME/.local/bin:$PATH"'

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) return ;;
  esac

  touch "$shell_rc"

  if ! grep -qF '$HOME/.local/bin' "$shell_rc"; then
    printf '\n%s\n' "$path_line" >>"$shell_rc"
  fi
}

install_omaterm_command() {
  local bin_dir="$HOME/.local/bin"
  local installer_dir raw_url

  mkdir -p "$bin_dir"

  installer_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "$installer_dir/bin/omaterm" ]; then
    cp "$installer_dir/bin/omaterm" "$bin_dir/omaterm"
  else
    raw_url="https://raw.githubusercontent.com/omacom-io/omaterm/refs/heads/${OMATERM_REF:-master}/bin/omaterm"
    curl -fsSL "$raw_url" -o "$bin_dir/omaterm"
  fi

  chmod +x "$bin_dir/omaterm"
  ensure_local_bin_on_path
  echo "✓ omaterm command"
}

run_docker_installation() {
  install_docker_packages

  if is_arch || is_debian || is_fedora; then
    section "Enabling Docker..."
    sudo systemctl enable --now docker.service
    sudo groupadd -f docker
    sudo usermod -aG docker "${USER:-$(id -un)}"
    echo "✓ Docker"
  fi

  install_omaterm_command

  section "Starting Omaterm..."
  if docker info >/dev/null 2>&1; then
    exec "$HOME/.local/bin/omaterm"
  elif command -v newgrp &>/dev/null && [ -t 0 ] && [ -r /dev/tty ]; then
    exec newgrp docker <<EOF
$HOME/.local/bin/omaterm
EOF
  else
    echo "Docker is installed, but your current shell does not have access yet."
    echo "Open a new shell, then run: omaterm"
    exit 1
  fi
}

banner
run_docker_installation
