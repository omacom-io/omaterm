#!/usr/bin/env bash
set -euo pipefail

OMATERM_BIN_DIR=/usr/local/bin

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
  elif [ -f /etc/arch-release ]; then
    sudo pacman -S --needed --noconfirm docker
  elif [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y docker.io
  elif [ -f /etc/fedora-release ]; then
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
  local base_url file tmp_file dest

  # The host CLI is omaterm plus the libraries it sources; ship them side by
  # side so the dirname-based `source` in omaterm resolves them.
  base_url="https://raw.githubusercontent.com/omacom-io/omaterm/refs/heads/${OMATERM_REF:-master}/bin/host"

  for file in omaterm omaterm-limits omaterm-templates omaterm-op; do
    tmp_file="$(mktemp)"
    curl -fsSL "$base_url/$file" -o "$tmp_file"
    dest="$OMATERM_BIN_DIR/$file"

    if ((EUID == 0)); then
      install -D -m 0755 "$tmp_file" "$dest"
    else
      sudo install -D -m 0755 "$tmp_file" "$dest"
    fi

    rm -f "$tmp_file"
  done

  echo "✓ Command"
}

banner

install_docker
install_omaterm_command

echo
echo "Run omaterm to get started"
