#!/usr/bin/env bash
set -euo pipefail

DOCKER_GROUP_REFRESH=0

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

detect_os() {
  if [ -f /etc/arch-release ]; then
    echo "arch"
  elif [ -f /etc/debian_version ]; then
    echo "debian"
  elif [ -f /etc/fedora-release ]; then
    echo "fedora"
  else
    return 1
  fi
}

as_root() {
  if [ "$EUID" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

read_package_file() {
  grep -vE '^[[:space:]]*(#|$)' "$1"
}

setup_omaterm_user() {
  local answer

  read -r -p "You can't install as root. Add omaterm user? [Y/n] " answer </dev/tty

  if [[ "$answer" =~ ^[Nn]([Oo])?$ ]]; then
    exit 1
  fi

  if ! id omaterm &>/dev/null; then
    useradd -m -s /bin/bash omaterm
    passwd omaterm
  fi

  mkdir -p /etc/sudoers.d
  printf 'omaterm ALL=(ALL) ALL\n' >/etc/sudoers.d/omaterm
  chmod 0440 /etc/sudoers.d/omaterm

  echo "Switching to omaterm. Run the Omaterm installer again from there."
  exec su - omaterm
}

install_omadots() {
  curl -fsSL https://raw.githubusercontent.com/omacom-io/omadots/refs/heads/master/install.sh | bash
}

install_mise_tools() {
  local -a mise_packages

  section "Installing mise tools..."
  eval "$(mise activate bash)" 2>/dev/null || true

  mapfile -t mise_packages < <(read_package_file "$INSTALLER_DIR/packaging/mise.packages")

  mise settings set idiomatic_version_file_enable_tools ruby
  mise use -g -y "${mise_packages[@]}"

  export PATH="$HOME/.local/share/mise/shims:$PATH"
}

install_configs() {
  section "Installing configs..."
  mkdir -p "$HOME/.config"
  cp -Rf "$INSTALLER_DIR/config/"* "$HOME/.config/"
  echo "✓ Neovim"
  echo "✓ Starship"

  local shell_rc="$HOME/.bashrc"

  if ! grep -qF '[[ -z $TMUX ]]' "$shell_rc" 2>/dev/null; then
    cat >>"$shell_rc" <<'EOF'

if [[ -z $TMUX ]]; then
  t
fi
EOF
    echo "✓ Tmux auto-start"
  fi
}

install_bins() {
  section "Installing bins..."
  mkdir -p "$HOME/.local/bin"
  cp -Rf "$INSTALLER_DIR/bin/"* "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/"*
  echo "✓ omaterm-theme"
  echo "✓ omaterm-refresh"
}

enable_docker() {
  local username

  sudo systemctl enable docker.service
  sudo systemctl start --no-block docker.service

  username="${USER:-$(id -un)}"

  if ! id -nG | grep -qw docker; then
    DOCKER_GROUP_REFRESH=1
  fi

  if ! id -nG "$username" | grep -qw docker; then
    if command -v usermod &>/dev/null; then
      sudo usermod -aG docker "$username"
    else
      sudo adduser "$username" docker
    fi
  fi

  echo "✓ Docker"
}

enable_ssh() {
  local ssh_service

  if systemctl cat sshd.service &>/dev/null; then
    ssh_service="sshd.service"
  elif systemctl cat ssh.service &>/dev/null; then
    ssh_service="ssh.service"
  else
    echo "Error: Could not find an SSH systemd service"
    return 1
  fi

  sudo systemctl enable --now "$ssh_service"
  echo "✓ sshd"
}

enable_services() {
  section "Enabling services..."

  enable_docker
  enable_ssh
}

run_first_setup() {
  section "First-run setup..."
  "$HOME/.local/bin/omaterm-setup"

  if [ "$DOCKER_GROUP_REFRESH" = "1" ] && command -v sg &>/dev/null; then
    exec sg docker -c 'exec bash -l'
  else
    exec bash -l
  fi
}

run_installation() {
  # OS-specific package installation
  install_packages

  # Omadots
  install_omadots

  # Configs and bins
  install_configs
  install_bins

  # Mise tooling
  install_mise_tools

  # OS-specific service enabling
  enable_services

  # First-run setup
  run_first_setup
}

# Getting started
show_banner
section "Installing Omaterm..."

if [ "$EUID" -eq 0 ]; then
  setup_omaterm_user
fi

if ! OS_ID="$(detect_os)"; then
  echo "Error: Unsupported operating system"
  echo "Omaterm supports Arch Linux, Debian/Ubuntu, and Fedora"
  exit 1
fi

# Ensure correct git is installed
if ! command -v git &>/dev/null; then
  case "$OS_ID" in
    arch) as_root pacman -Syu --needed --noconfirm git ;;
    debian) as_root apt-get update && as_root apt-get install -y git ;;
    fedora) as_root dnf install -y git ;;
  esac
fi

REPO="https://github.com/omacom-io/omaterm.git"
OMATERM_REF="${OMATERM_REF:-master}"
INSTALLER_DIR="$(mktemp -d)"
trap 'rm -rf "$INSTALLER_DIR"' EXIT

echo "Cloning Omaterm from $REPO ($OMATERM_REF)..."
git clone --depth 1 --branch "$OMATERM_REF" "$REPO" "$INSTALLER_DIR"

# OS detection and dispatch
case "$OS_ID" in
  arch) source "$INSTALLER_DIR/packaging/arch.sh" ;;
  debian) source "$INSTALLER_DIR/packaging/debian.sh" ;;
  fedora) source "$INSTALLER_DIR/packaging/fedora.sh" ;;
esac

run_installation
