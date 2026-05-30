#!/usr/bin/env bash
set -euo pipefail

section() {
  echo -e "\n==> $1"
}

ensure_arch_installation() {
  if [ ! -f /etc/arch-release ]; then
    echo "Error: Native installation requires Arch Linux."
    echo "Use install-docker.sh instead."
    exit 1
  fi
}

setup_omaterm_user_when_root() {
  if [ "$EUID" -eq 0 ]; then
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
  fi
}

setup_arch_package_repositories() {
  section "Configuring Omarchy package repository and mirror..."

  sudo tee /etc/pacman.d/mirrorlist >/dev/null <<'EOF'
Server = https://mirror.omarchy.org/$repo/os/$arch
EOF

  if grep -qxF "[omarchy]" /etc/pacman.conf; then
    sudo sed -i '/^\[omarchy\]$/,/^\[/{s|^SigLevel = .*|SigLevel = Optional TrustAll|; s|^Server = https://pkgs\.omarchy\.org/[^/]*/\$arch|Server = https://pkgs.omarchy.org/edge/$arch|}' /etc/pacman.conf
  else
    sudo tee -a /etc/pacman.conf >/dev/null <<'EOF'

[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/edge/$arch
EOF
  fi
}

setup_git_checkout() {
  local omaterm_ref repo

  sudo pacman -Syu --needed --noconfirm git

  repo="https://github.com/omacom-io/omaterm.git"
  omaterm_ref="${OMATERM_REF:-master}"
  INSTALLER_DIR="$(mktemp -d)"
  trap 'rm -rf "$INSTALLER_DIR"' EXIT

  echo "Cloning Omaterm from $repo ($omaterm_ref)..."
  git clone --depth 1 --branch "$omaterm_ref" "$repo" "$INSTALLER_DIR"
}

install_packages() {
  local -a official_pkgs
  mapfile -t official_pkgs < <(grep -vE '^[[:space:]]*(#|$)' "$INSTALLER_DIR/arch.packages")

  section "Installing Arch packages..."
  sudo pacman -Syu --needed --noconfirm "${official_pkgs[@]}"
  reboot_if_kernel_upgraded
}

reboot_if_kernel_upgraded() {
  if [ -d "/lib/modules/$(uname -r)" ]; then
    return
  fi

  section "Kernel was upgraded during package install"
  echo "The running kernel ($(uname -r)) no longer has matching modules on disk,"
  echo "so services like tailscaled, docker, and iptables will fail to start."
  echo "A reboot is required before Omaterm setup can continue."
  echo

  if gum confirm "Reboot now and re-run the Omaterm installer afterwards?"; then
    sudo systemctl reboot
    exit 0
  fi

  echo "Aborting. Reboot and re-run the Omaterm installer to continue."
  exit 1
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
}

install_bins() {
  section "Installing bins..."
  mkdir -p "$HOME/.local/bin"
  cp -Rf "$INSTALLER_DIR/bin/"* "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/"*
  echo "✓ omaterm-theme"
  echo "✓ omaterm-refresh"
}

install_mise_tools() {
  local -a mise_packages

  section "Installing AI tooling..."
  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
  eval "$(mise activate bash)" 2>/dev/null || true

  mapfile -t mise_packages < <(grep -vE '^[[:space:]]*(#|$)' "$INSTALLER_DIR/mise.packages")

  mise settings set idiomatic_version_file_enable_tools ruby
  mise use -g -y "${mise_packages[@]}"

  export PATH="$HOME/.local/share/mise/shims:$PATH"
}

enable_services() {
  section "Enabling services..."

  sudo systemctl enable docker.service
  sudo systemctl start --no-block docker.service
  sudo usermod -aG docker "${USER:-$(id -un)}"
  echo "✓ Docker"

  sudo systemctl enable --now sshd.service
  echo "✓ sshd"
}

run_first_setup() {
  section "First-run setup..."
  "$HOME/.local/bin/omaterm-setup"
  exec sg docker -c 'exec bash -l </dev/tty'
}

ensure_arch_installation
setup_omaterm_user_when_root
setup_arch_package_repositories
setup_git_checkout

install_packages
install_omadots
install_configs
install_bins
install_mise_tools

enable_services
run_first_setup
