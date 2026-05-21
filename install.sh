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

prompt_confirm() {
  local prompt="$1"
  local default="${2:-y}"
  local suffix reply

  if [ "$default" = "y" ]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi

  while true; do
    printf "%s %s " "$prompt" "$suffix" >/dev/tty
    IFS= read -r reply </dev/tty || return 1
    reply="${reply,,}"

    case "$reply" in
    "") [ "$default" = "y" ] && return 0 || return 1 ;;
    y | yes) return 0 ;;
    n | no) return 1 ;;
    *) echo "Please answer yes or no." >/dev/tty ;;
    esac
  done
}

default_install_user() {
  local users

  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    echo "$SUDO_USER"
    return
  fi

  mapfile -t users < <(awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "nobody" { print $1 }' /etc/passwd)
  if [ "${#users[@]}" -eq 1 ]; then
    echo "${users[0]}"
  else
    echo "omaterm"
  fi
}

prompt_username() {
  local default_user="$1"
  local username

  while true; do
    printf "User to use/create [%s]: " "$default_user" >/dev/tty
    IFS= read -r username </dev/tty || return 1
    username="${username:-$default_user}"

    if [ "$username" = "root" ]; then
      echo "Please choose a non-root user." >/dev/tty
    elif [[ "$username" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
      echo "$username"
      return 0
    else
      echo "Use a Linux username like 'omaterm' or 'alice'." >/dev/tty
    fi
  done
}

ensure_root_bootstrap_tools() {
  local os_id="$1"

  if command -v sudo &>/dev/null; then
    return
  fi

  section "Installing sudo..."
  case "$os_id" in
  arch)
    pacman -Syu --needed --noconfirm sudo
    ;;
  debian)
    apt-get update
    apt-get install -y sudo
    ;;
  fedora)
    dnf install -y sudo
    ;;
  esac
}

admin_group_for_os() {
  case "$1" in
  debian) echo "sudo" ;;
  arch | fedora) echo "wheel" ;;
  esac
}

ensure_install_user() {
  local username="$1"
  local os_id="$2"
  local admin_group

  if getent passwd "$username" &>/dev/null; then
    echo "✓ Using existing user: $username"
  else
    section "Creating user $username..."
    useradd -m -s /bin/bash "$username"
    echo "Set a password for $username. You'll use it for sudo during install."
    passwd "$username" </dev/tty
  fi

  admin_group="$(admin_group_for_os "$os_id")"
  getent group "$admin_group" &>/dev/null || groupadd "$admin_group"
  usermod -aG "$admin_group" "$username"

  mkdir -p /etc/sudoers.d
  printf "%%%s ALL=(ALL:ALL) ALL\n" "$admin_group" >"/etc/sudoers.d/10-omaterm-$admin_group"
  chmod 0440 "/etc/sudoers.d/10-omaterm-$admin_group"
  echo "✓ Added $username to $admin_group"
}

maybe_reexec_as_non_root() {
  local os_id="$1"
  local installer_dir="$2"
  local default_user target_user status

  if [ "$EUID" -ne 0 ] || [ "${OMATERM_ALLOW_ROOT:-}" = "1" ]; then
    return
  fi

  if [ ! -r /dev/tty ] || [ ! -w /dev/tty ]; then
    echo "Running as root without an interactive TTY; continuing as root."
    ensure_root_bootstrap_tools "$os_id"
    return
  fi

  echo
  echo "Omaterm is running as root. If we continue, user config will be installed under /root."
  echo "It's usually better to install Omaterm as a normal sudo-capable user."

  if ! prompt_confirm "Create/use a non-root user and run the install there instead?" "y"; then
    echo "Continuing as root. Set OMATERM_ALLOW_ROOT=1 to skip this prompt."
    ensure_root_bootstrap_tools "$os_id"
    return
  fi

  default_user="$(default_install_user)"
  target_user="$(prompt_username "$default_user")"

  ensure_root_bootstrap_tools "$os_id"
  ensure_install_user "$target_user" "$os_id"

  section "Restarting installer as $target_user..."
  chmod -R a+rX "$installer_dir"

  if sudo -iu "$target_user" env OMATERM_REF="$OMATERM_REF" bash "$installer_dir/install.sh"; then
    echo
    echo "Omaterm installed for $target_user. You're back at the root shell."
    echo "To start using Omaterm, either log out and log back in as $target_user, or run:"
    echo "  su - $target_user"
    exit 0
  else
    status=$?
    echo
    echo "Omaterm install failed for $target_user. You're back at the root shell."
    exit "$status"
  fi
}

install_omadots() {
  curl -fsSL https://raw.githubusercontent.com/hattapauzi/omadots/main/install.sh | bash
}

install_configs() {
  section "Installing configs..."
  mkdir -p "$HOME/.config"
  cp -Rf "$INSTALLER_DIR/config/"* "$HOME/.config/"
  echo "✓ Neovim"
  echo "✓ Starship"

  local shell_rc
  case "$(basename "$SHELL")" in
  zsh) shell_rc="$HOME/.zshrc" ;;
  *) shell_rc="$HOME/.bashrc" ;;
  esac

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
  echo "✓ omaterm-ssh"
  echo "✓ omaterm-theme"
  echo "✓ omaterm-refresh"
}

configure_shell() {
  section "Configuring shell..."
  local username zsh_path current_shell

  username="${USER:-$(id -un)}"
  zsh_path="$(command -v zsh)"
  current_shell="$(getent passwd "$username" | cut -d: -f7)"

  if [ "$current_shell" != "$zsh_path" ]; then
    as_root usermod -s "$zsh_path" "$username"
  fi

  export SHELL="$zsh_path"
  echo "✓ Zsh"
}

install_mise_tools() {
  section "Installing Ruby + Node..."
  eval "$(mise activate bash)" 2>/dev/null || true

  mise use -g node

  mise settings set ruby.compile false
  mise settings set idiomatic_version_file_enable_tools ruby
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

  # Make Zsh the default shell before Omadots writes shell config
  configure_shell

  # Omadots
  install_omadots

  # Configs and bins
  install_configs
  install_bins

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

# Getting started
show_banner
section "Installing Omaterm..."

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
maybe_reexec_as_non_root "$OS_ID" "$INSTALLER_DIR"

# OS detection and dispatch
case "$OS_ID" in
arch) source "$INSTALLER_DIR/install/arch.sh" ;;
debian) source "$INSTALLER_DIR/install/debian.sh" ;;
fedora) source "$INSTALLER_DIR/install/fedora.sh" ;;
esac

run_installation
