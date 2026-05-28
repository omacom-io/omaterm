install_packages() {
  local -a packages

  mapfile -t packages < <(read_package_file "$INSTALLER_DIR/install/debian.packages")

  section "Updating system packages..."
  sudo apt-get update
  sudo apt-get upgrade -y

  section "Installing Debian packages..."
  sudo apt-get remove -y containerd.io 2>/dev/null || true
  sudo apt-get install -y "${packages[@]}"

  # tailscale (not in Debian/Ubuntu repos)
  if ! command -v tailscale &>/dev/null; then
    section "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  # mise (not in Ubuntu repos)
  if ! command -v mise &>/dev/null; then
    section "Installing mise..."
    curl -fsSL https://mise.run | sh 2>/dev/null
    export PATH="$HOME/.local/bin:$PATH"
  fi
}
