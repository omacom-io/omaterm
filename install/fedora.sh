install_packages() {
  local -a packages

  mapfile -t packages < <(read_package_file "$INSTALLER_DIR/install/fedora.packages")

  section "Updating system packages..."
  sudo dnf upgrade -y

  section "Installing Fedora packages..."
  sudo dnf install -y "${packages[@]}"

  # Docker (not in Fedora repos, needs Docker's official repo)
  if ! command -v docker &>/dev/null; then
    section "Installing Docker..."
    sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  fi

  # mise (not in Fedora repos)
  if ! command -v mise &>/dev/null; then
    section "Installing mise..."
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
}
