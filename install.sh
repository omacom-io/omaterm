#!/usr/bin/env bash
set -euo pipefail

OMATERM_COMMAND=/usr/local/bin/omaterm

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

install_docker() {
  section "Installing Docker..."

  if is_wsl; then
    if docker info >/dev/null 2>&1; then
      return
    fi

    echo "Error: Docker is not available."
    echo "Install and start Docker Desktop for Windows with WSL integration enabled, then re-run this installer."
    exit 1
  fi

  if command -v docker &>/dev/null && systemctl cat docker.service &>/dev/null; then
    :
  elif is_arch; then
    sudo pacman -S --needed --noconfirm docker
  elif is_debian; then
    sudo apt-get update
    sudo apt-get install -y docker.io
  elif is_fedora; then
    sudo dnf install -y moby-engine
  else
    echo "Error: This OS is not supported by the installer."
    echo "Install Docker manually, then run this installer again."
    exit 1
  fi

  section "Enabling Docker..."
  sudo systemctl enable --now docker.service
  sudo groupadd -f docker
  sudo usermod -aG docker "${USER:-$(id -un)}"

  echo
  echo "✓ Docker"
}

install_omaterm_command() {
  local raw_url tmp_file

  raw_url="https://raw.githubusercontent.com/omacom-io/omaterm/refs/heads/${OMATERM_REF:-master}/bin/omaterm"
  tmp_file="$(mktemp)"
  curl -fsSL "$raw_url" -o "$tmp_file"

  if ((EUID == 0)); then
    install -D -m 0755 "$tmp_file" "$OMATERM_COMMAND"
  else
    sudo install -D -m 0755 "$tmp_file" "$OMATERM_COMMAND"
  fi

  rm -f "$tmp_file"

  echo "✓ omaterm command"
}

banner

install_docker
install_omaterm_command

echo
echo "Run omaterm to get started"

if ! is_wsl; then
  newgrp docker
fi
