#!/usr/bin/env bash
set -euo pipefail

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

docker_run_command() {
  cat <<'EOF'
if [ -r /dev/tty ]; then
  exec </dev/tty
fi

if docker container inspect omaterm >/dev/null 2>&1; then
  exec docker start -ai omaterm
else
  exec docker run -it --name omaterm --net host -v /var/run/docker.sock:/var/run/docker.sock ghcr.io/omacom-io/omaterm
fi
EOF
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

install_docker_alias() {
  local alias_file alias_line

  alias_line="alias omaterm='docker start -ai omaterm'"

  if is_debian || is_wsl; then
    alias_file="$HOME/.bash_aliases"
  else
    alias_file="$HOME/.bashrc"
  fi

  touch "$alias_file"

  if ! grep -qF "$alias_line" "$alias_file"; then
    printf '\n%s\n' "$alias_line" >>"$alias_file"
  fi

  if is_debian || is_wsl; then
    touch "$HOME/.bashrc"

    if ! grep -qF '. ~/.bash_aliases' "$HOME/.bashrc"; then
      cat >>"$HOME/.bashrc" <<'EOF'

if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi
EOF
    fi
  fi

  echo "✓ omaterm alias"
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

  install_docker_alias

  section "Starting Omaterm..."
  if is_arch || is_debian || is_fedora; then
    exec sg docker -c "$(docker_run_command)" </dev/tty
  else
    eval "$(docker_run_command)"
  fi
}

run_docker_installation
