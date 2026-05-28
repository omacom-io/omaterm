# syntax=docker/dockerfile:1
FROM archlinux:latest

# Use all cores for compilation
RUN echo "MAKEFLAGS=\"-j$(nproc)\"" >> /etc/makepkg.conf

COPY install/arch.packages /tmp/arch.packages

# Update system and install official packages
RUN pacman -Syu --needed --noconfirm $(grep -vE '^[[:space:]]*(#|$)' /tmp/arch.packages) && \
    pacman -Scc --noconfirm

# Create a non-root user
RUN useradd -m -u 1000 -s /bin/bash omaterm && \
    echo "omaterm ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/omaterm && \
    chmod 0440 /etc/sudoers.d/omaterm

USER omaterm
WORKDIR /home/omaterm
ENV SHELL=/bin/bash
ENV OMATERM_DOCKER=1
ENV MISE_JOBS=1

# Install yay
RUN git clone https://aur.archlinux.org/yay-bin.git /tmp/yay && \
    cd /tmp/yay && makepkg -si --noconfirm && \
    rm -rf /tmp/yay

# Install omadots
RUN curl -fsSL https://raw.githubusercontent.com/omacom-io/omadots/refs/heads/master/install.sh | bash

# Copy configs and bins
COPY --chown=omaterm:omaterm config/ /home/omaterm/.config/
COPY --chown=omaterm:omaterm bin/ /home/omaterm/.local/bin/
COPY --chown=omaterm:omaterm install/mise.packages /tmp/mise.packages
RUN chmod +x /home/omaterm/.local/bin/*

# Auto-start tmux in .bashrc
RUN cat >> /home/omaterm/.bashrc <<'EOF'

if [[ -z $TMUX ]]; then
  t
fi
EOF

# Install user tools via mise
# Do not bake BuildKit's GPG/keyboxd state into runtime containers.
RUN --mount=type=secret,id=GITHUB_TOKEN,required=true,uid=1000,gid=1000 \
    github_token="$(cat /run/secrets/GITHUB_TOKEN)" && \
    export GITHUB_TOKEN="$github_token" GH_TOKEN="$github_token" && \
    eval "$(mise activate bash)" && \
    mise settings set jobs 1 && \
    mise settings set idiomatic_version_file_enable_tools ruby && \
    mise use -g -y --jobs=1 $(grep -vE '^[[:space:]]*(#|$)' /tmp/mise.packages) && \
    (gpgconf --kill all || true) && \
    rm -rf /home/omaterm/.gnupg

ENV PATH="/home/omaterm/.local/share/mise/shims:/home/omaterm/.local/bin:${PATH}"

USER root
ENTRYPOINT ["/home/omaterm/.local/bin/omaterm-entrypoint"]
