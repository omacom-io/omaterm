setup_arch_package_repositories() {
  section "Configuring Omarchy package repository..."

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

install_packages() {
  local -a official_pkgs

  mapfile -t official_pkgs < <(read_package_file "$INSTALLER_DIR/packaging/arch.packages")

  setup_arch_package_repositories

  section "Installing Arch packages..."
  sudo pacman -Syu --needed --noconfirm "${official_pkgs[@]}"
}
