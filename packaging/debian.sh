setup_debian_tool_repositories() {
  section "Configuring CLI package repositories..."

  sudo install -d -m 0755 /etc/apt/keyrings /usr/share/keyrings

  if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
      sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  fi

  if [ ! -f /etc/apt/sources.list.d/charm.list ]; then
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" |
      sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
  fi

  if [ ! -f /etc/apt/sources.list.d/1password.list ]; then
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
      sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" |
      sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
    sudo install -d -m 0755 /etc/debsig/policies/AC2D62742012EA22 /usr/share/debsig/keyrings/AC2D62742012EA22
    curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol |
      sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
      sudo gpg --batch --yes --dearmor -o /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
  fi

  if [ ! -f /etc/apt/sources.list.d/gierens.list ]; then
    curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc |
      sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" |
      sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo chmod 0644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  fi
}

install_starship() {
  if ! command -v starship &>/dev/null; then
    section "Installing Starship..."
    curl -fsSL https://starship.rs/install.sh | sudo sh -s -- -y
  fi
}

install_lazygit() {
  local arch latest_url version tmpdir

  if command -v lazygit &>/dev/null; then
    return 0
  fi

  if apt-cache show lazygit &>/dev/null; then
    sudo apt-get install -y lazygit
    return 0
  fi

  section "Installing lazygit..."

  case "$(uname -m)" in
    x86_64 | amd64) arch="x86_64" ;;
    aarch64 | arm64) arch="arm64" ;;
    *)
      echo "Error: unsupported architecture for lazygit: $(uname -m)" >&2
      return 1
      ;;
  esac

  latest_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/jesseduffield/lazygit/releases/latest)"
  version="${latest_url##*/v}"
  tmpdir="$(mktemp -d)"
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${arch}.tar.gz" |
    tar -xz -C "$tmpdir" lazygit
  sudo install -m 0755 "$tmpdir/lazygit" /usr/local/bin/lazygit
  rm -rf "$tmpdir"
}

install_packages() {
  local -a packages

  mapfile -t packages < <(read_package_file "$INSTALLER_DIR/packaging/debian.packages")

  section "Updating system packages..."
  sudo apt-get update
  sudo apt-get upgrade -y
  setup_debian_tool_repositories
  sudo apt-get update

  section "Installing Debian packages..."
  sudo apt-get remove -y containerd.io 2>/dev/null || true
  sudo apt-get install -y "${packages[@]}"
  install_starship
  install_lazygit

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
