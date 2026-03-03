install_packages() {
  section "Updating system packages..."
  sudo dnf upgrade -y

  section "Installing Fedora packages..."
  sudo dnf install -y @development-tools \
    git openssh-server sudo less net-tools whois \
    fzf zoxide tmux btop jq man-db tldr \
    vim neovim luarocks \
    clang llvm rust cargo libyaml \
    curl wget \
    gh tailscale

  # starship (not in Fedora repos)
  if ! command -v starship &>/dev/null; then
    section "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
  fi

  # eza (not in Fedora repos)
  if ! command -v eza &>/dev/null; then
    section "Installing eza..."
    cargo install eza
  fi

  # Docker (not in Fedora repos, needs Docker's official repo)
  if ! command -v docker &>/dev/null; then
    section "Installing Docker..."
    sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  # lazygit (via COPR)
  if ! command -v lazygit &>/dev/null; then
    section "Installing lazygit..."
    sudo dnf copr enable -y atim/lazygit
    sudo dnf install -y lazygit
  fi

  # lazydocker (not in repos)
  if ! command -v lazydocker &>/dev/null; then
    section "Installing lazydocker..."
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
  fi

  # gum (from Charm repo)
  if ! command -v gum &>/dev/null; then
    section "Installing gum..."
    echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
    sudo dnf install -y gum
  fi

  # mise (not in Fedora repos)
  if ! command -v mise &>/dev/null; then
    section "Installing mise..."
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

install_npm_tools() {
  section "Installing AI coding assistants..."
  if ! command -v opencode &>/dev/null; then
    npm install -g opencode-ai
  fi
  if ! command -v claude-code &>/dev/null; then
    npm install -g @anthropic-ai/claude-code
  fi
}

enable_services() {
  section "Enabling services..."

  sudo systemctl enable --now docker.service
  echo "✓ Docker"

  sudo systemctl enable --now sshd.service
  echo "✓ sshd"
}
