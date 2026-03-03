install_packages() {
  local official_pkgs=(
    base-devel git openssh sudo less inetutils whois
    starship fzf eza zoxide tmux btop jq gum man-db tldr
    vim neovim luarocks
    clang llvm rust mise libyaml
    github-cli lazygit lazydocker opencode
    docker docker-buildx docker-compose
    tailscale
  )

  local aur_pkgs=(
    claude-code
  )

  section "Installing Arch packages..."
  sudo pacman -Syu --needed --noconfirm "${official_pkgs[@]}"

  if ! command -v yay &>/dev/null; then
    section "Installing yay..."
    local tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
  fi

  section "Installing AUR packages..."
  yay -S --needed --noconfirm "${aur_pkgs[@]}"
}

install_npm_tools() {
  :
}

enable_services() {
  section "Enabling services..."

  sudo systemctl enable --now docker.service
  echo "✓ Docker"

  sudo systemctl enable --now sshd.service
  echo "✓ sshd"
}
