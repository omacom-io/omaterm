#!/usr/bin/env bash
set -euo pipefail

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

install_omadots() {
  curl -fsSL https://raw.githubusercontent.com/omacom-io/omadots/refs/heads/master/install.sh | bash
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

  install_shell_helpers "$shell_rc"
}

install_shell_helpers() {
  local shell_rc="$1"

  if grep -qF '# Omaterm shell helpers' "$shell_rc" 2>/dev/null; then
    return
  fi

  cat >>"$shell_rc" <<'EOF'

# Omaterm shell helpers
op-unlock() {
  local -a signin_args=()

  command -v op >/dev/null || return 127

  if op whoami >/dev/null 2>&1; then
    echo "✓ 1Password unlocked"
    return 0
  fi

  if ! op account list --format json 2>/dev/null | jq -e 'length > 0' >/dev/null; then
    echo "No 1Password CLI account configured. Adding one now."
    op account add || return
  fi

  if [ -n "${OP_ACCOUNT:-}" ]; then
    signin_args+=(--account "$OP_ACCOUNT")
  fi

  eval "$(op signin "${signin_args[@]}")"
  op whoami >/dev/null && echo "✓ 1Password unlocked"
}
EOF
  echo "✓ 1Password helper"
}

install_bins() {
  section "Installing bins..."
  mkdir -p "$HOME/.local/bin"
  cp -Rf "$INSTALLER_DIR/bin/"* "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/"*
  echo "✓ omaterm-theme"
  echo "✓ omaterm-refresh"
}

configure_shell() {
  section "Configuring shell..."
  local username bash_path current_shell

  username="${USER:-$(id -un)}"
  bash_path="$(command -v bash)"
  current_shell="$(getent passwd "$username" | cut -d: -f7)"

  if [ "$current_shell" != "$bash_path" ]; then
    as_root usermod -s "$bash_path" "$username"
  fi

  export SHELL="$bash_path"
  echo "✓ Bash"
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

setup_docker_group() {
  local username

  username="${USER:-$(id -un)}"

  if ! id -nG "$username" | grep -qw docker; then
    if command -v usermod &>/dev/null; then
      sudo usermod -aG docker "$username"
    else
      sudo adduser "$username" docker
    fi
  fi
}

enable_docker() {
  sudo systemctl enable docker.service
  sudo systemctl start --no-block docker.service
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

signin_1password() {
  local -a signin_args=()

  if [ -n "${OP_ACCOUNT:-}" ]; then
    signin_args+=(--account "$OP_ACCOUNT")
  fi

  eval "$(op signin "${signin_args[@]}")"
  op whoami >/dev/null
}

setup_1password() {
  command -v op &>/dev/null || return 0
  op whoami &>/dev/null && return 0

  echo
  if ! gum confirm "Authenticate with 1Password?" </dev/tty; then
    return 0
  fi

  if ! op account list --format json 2>/dev/null | jq -e 'length > 0' >/dev/null; then
    op account add
  fi

  signin_1password
  echo "✓ 1Password"
}

interactive_setup() {
  section "Interactive setup..."

  if ! gh auth status &>/dev/null; then
    echo
    if gum confirm "Authenticate with GitHub?" </dev/tty; then
      gh auth login
    fi
  fi

  setup_1password

  if ! tailscale status &>/dev/null; then
    echo
    if gum confirm "Connect to Tailscale network?" </dev/tty; then
      echo "This might take a minute..."
      sudo systemctl enable --now tailscaled.service
      sudo tailscale up --ssh --accept-routes
    fi
  fi

  if grep -qi proxmox /sys/class/dmi/id/product_name 2>/dev/null && [ -e /dev/ttyS0 ]; then
    if ! systemctl is-enabled serial-getty@ttyS0.service &>/dev/null; then
      echo
      if gum confirm "Proxmox VM detected with serial port. Enable serial console?" </dev/tty; then
        sudo systemctl enable serial-getty@ttyS0.service
        sudo systemctl start serial-getty@ttyS0.service
        echo "✓ Serial console enabled on ttyS0"
      fi
    fi
  fi
}

finish() {
  section "Finished!"
  echo "Now logout and back in for everything to take effect"
}

configure_parallel_builds() {
  section "Configuring parallel compilation..."
  export MAKEFLAGS="-j$(nproc)"

  if [ -f /etc/makepkg.conf ]; then
    sudo sed -i "s/^#\?MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf
  fi

  echo "✓ Using $(nproc) cores for compilation"
}

run_installation() {
  # Use all cores for compilation
  configure_parallel_builds

  # OS-specific package installation
  install_packages

  # Make Bash the default shell before Omadots writes shell config
  configure_shell

  # Omadots
  install_omadots

  # Configs and bins
  install_configs
  install_bins

  # Mise tooling
  install_mise_tools

  # OS-specific service enabling
  enable_services

  # Setup Docker group
  setup_docker_group

  # Interactive setup
  interactive_setup

  # Done!
  finish
}

# Getting started
show_banner
section "Installing Omaterm..."

if [ "$EUID" -eq 0 ]; then
  echo "Error: Do not run the Omaterm installer as root."
  echo "Log in as a normal sudo-capable user and run it again."
  exit 1
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
