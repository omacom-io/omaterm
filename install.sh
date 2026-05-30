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

is_arch() {
  [ -f /etc/arch-release ]
}

install_natively_on_arch() {
  local answer

  if ! is_arch; then
    return 1
  fi

  read -r -p "Install natively or via Docker? [N/d] " answer </dev/tty
  [[ ! "$answer" =~ ^[Dd]([Oo][Cc][Kk][Ee][Rr])?$ ]]
}

run_installer() {
  local installer="$1"
  local installer_dir raw_url

  installer_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [ -f "$installer_dir/$installer" ]; then
    exec bash "$installer_dir/$installer"
  fi

  raw_url="https://raw.githubusercontent.com/omacom-io/omaterm/refs/heads/${OMATERM_REF:-master}/$installer"
  curl -fsSL "$raw_url" | bash
}

banner

if install_natively_on_arch; then
  run_installer install-native.sh
else
  run_installer install-docker.sh
fi
