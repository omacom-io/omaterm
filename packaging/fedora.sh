setup_fedora_tool_repositories() {
  section "Configuring CLI package repositories..."

  if [ ! -f /etc/yum.repos.d/gh-cli.repo ]; then
    sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
  fi

  if [ ! -f /etc/yum.repos.d/charm.repo ]; then
    cat <<'EOF' | sudo tee /etc/yum.repos.d/charm.repo >/dev/null
[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key
EOF
    sudo rpm --import https://repo.charm.sh/yum/gpg.key
  fi

  if [ ! -f /etc/yum.repos.d/1password.repo ]; then
    sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
    cat <<'EOF' | sudo tee /etc/yum.repos.d/1password.repo >/dev/null
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
  fi
}

install_eza() {
  if ! command -v eza &>/dev/null; then
    section "Installing eza..."
    cargo install --root "$HOME/.local" eza
  fi
}

install_packages() {
  local -a packages

  mapfile -t packages < <(read_package_file "$INSTALLER_DIR/packaging/fedora.packages")

  section "Updating system packages..."
  sudo dnf upgrade -y
  setup_fedora_tool_repositories

  section "Installing Fedora packages..."
  sudo dnf install -y "${packages[@]}"
  install_eza

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
