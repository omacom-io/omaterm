install_packages() {
  section "Updating system packages..."
  sudo apt-get update
  sudo apt-get upgrade -y

  section "Installing Debian packages..."
  sudo apt-get install -y \
    build-essential git openssh-server libssl-dev sudo less net-tools whois \
    fzf eza zoxide tmux btop jq man-db \
    vim neovim luarocks \
    clang llvm rustc libyaml-0-2 \
    curl wget gpg \
    docker.io docker-buildx docker-compose

  # tldr: Debian Trixie+ replaced tldr with tealdeer
  if apt-cache show tealdeer &>/dev/null; then
    sudo apt-get install -y tealdeer
  else
    sudo apt-get install -y tldr
  fi

  # github-cli (not in Debian/Ubuntu repos)
  if ! command -v gh &>/dev/null; then
    section "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
    sudo apt-get update
    sudo apt-get install -y gh
  fi

  # tailscale (not in Debian/Ubuntu repos)
  if ! command -v tailscale &>/dev/null; then
    section "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  # starship (not in Debian/Ubuntu repos)
  if ! command -v starship &>/dev/null; then
    section "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
  fi

  # lazygit (not in Ubuntu repos)
  if ! command -v lazygit &>/dev/null; then
    section "Installing lazygit..."
    local LAZYGIT_VERSION
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit /usr/local/bin/
    rm -f /tmp/lazygit.tar.gz /tmp/lazygit
  fi

  # lazydocker (not in Ubuntu repos)
  if ! command -v lazydocker &>/dev/null; then
    section "Installing lazydocker..."
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
  fi

  # gum (from Charm apt repo)
  if ! command -v gum &>/dev/null; then
    section "Installing gum..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt-get update
    sudo apt-get install -y gum
  fi

  # mise (not in Ubuntu repos)
  if ! command -v mise &>/dev/null; then
    section "Installing mise..."
    curl -fsSL https://mise.run | sh 2>/dev/null
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

  sudo systemctl enable --now ssh.service
  echo "✓ sshd"
}
