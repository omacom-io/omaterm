FROM archlinux:latest

# Use all cores for compilation
RUN echo "MAKEFLAGS=\"-j$(nproc)\"" >> /etc/makepkg.conf

# Update system and install official packages
RUN pacman -Syu --needed --noconfirm \
      base-devel git openssh sudo less inetutils whois \
      starship fzf eza zoxide tmux btop jq gum man-db tldr \
      vim neovim luarocks \
      clang llvm rust mise libyaml \
      github-cli lazygit lazydocker opencode \
      docker docker-buildx docker-compose \
      kitty-terminfo && \
    pacman -Scc --noconfirm

# Create a non-root user (needed for makepkg/yay)
RUN useradd -m -s /bin/bash omaterm && \
    echo "omaterm ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/omaterm

USER omaterm
WORKDIR /home/omaterm

# Install yay
RUN git clone https://aur.archlinux.org/yay-bin.git /tmp/yay && \
    cd /tmp/yay && makepkg -si --noconfirm && \
    rm -rf /tmp/yay

# Install AUR packages
RUN yay -S --needed --noconfirm claude-code

# Install omadots
RUN curl -fsSL https://raw.githubusercontent.com/omacom-io/omadots/refs/heads/master/install.sh | bash

# Copy configs and bins
COPY --chown=omaterm:omaterm config/ /home/omaterm/.config/
COPY --chown=omaterm:omaterm bin/ /home/omaterm/.local/bin/
RUN chmod +x /home/omaterm/.local/bin/*

# Auto-start tmux in .bashrc
RUN echo 'if [[ -z $TMUX ]]; then t; fi' >> /home/omaterm/.bashrc

# Install Ruby + Node via mise
RUN eval "$(mise activate bash)" && \
    mise use -g node && \
    mise settings set ruby.compile false && \
    mise settings set idiomatic_version_file_enable_tools ruby && \
    mise use -g ruby

ENV PATH="/home/omaterm/.local/share/mise/shims:/home/omaterm/.local/bin:${PATH}"

ENTRYPOINT ["/home/omaterm/.local/bin/omaterm-setup"]
