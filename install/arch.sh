install_packages() {
  local -a official_pkgs

  mapfile -t official_pkgs < <(read_package_file "$INSTALLER_DIR/install/arch.packages")

  section "Installing Arch packages..."
  sudo pacman -Syu --needed --noconfirm "${official_pkgs[@]}"

  if ! command -v yay &>/dev/null; then
    section "Installing yay..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
  fi
}
