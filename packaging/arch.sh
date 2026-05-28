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

install_packages() {
  local -a official_pkgs

  mapfile -t official_pkgs < <(read_package_file "$INSTALLER_DIR/packaging/arch.packages")

  setup_arch_package_repositories

  section "Installing Arch packages..."
  sudo pacman -Syu --needed --noconfirm "${official_pkgs[@]}"
  reboot_if_kernel_upgraded
}
