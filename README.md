# Omaterm

An Omakase Terminal Setup For Arch/Debian/Ubuntu/Fedora/Docker by DHH. Think of it as a headless [Omarchy](https://omarchy.org).

## Requirements

- Base Arch/Debian/Ubuntu/Fedora Linux installation (or ability to start Docker)
- Internet connection
- `sudo` privileges

## Install directly

This will automatically detect your host OS and install the correct packages accordingly:

```bash
curl -fsSL https://omaterm.org/install | bash
```

## Install via Docker

```bash
docker run -it --name omaterm --privileged --cgroupns=host ghcr.io/omacom-io/omaterm
```

The first run starts an interactive setup, including prompts to set the `omaterm` sudo password, add an SSH public key, and connect to Tailscale with a Tailnet hostname. Inside Docker, Tailscale runs in userspace networking mode and restarts automatically with the named container.

Omaterm uses Docker-in-Docker by default, so Docker images, volumes, and databases are isolated inside the named container. If you prefer to use the host Docker engine instead:

```bash
docker run -it --name omaterm -e OMATERM_DOCKER_HOST=1 -v /var/run/docker.sock:/var/run/docker.sock ghcr.io/omacom-io/omaterm
```

Then setup this alias in your shell to be able to start omaterm easily:

```bash
alias omaterm='docker start -ai omaterm'
```

The named container persists its filesystem across starts, including home directory state, installed packages, git config, shell history, and projects. Remove it with `docker rm omaterm` when you want to reset.

## What it sets up

- **Shell**: Bash with starship prompt, fzf, eza, zoxide, and tmux
- **Editors**: Neovim (LazyVim)
- **Agents**: opencode, claude-code, codex, gemini
- **Dev tools**: mise, docker, GitHub CLI (`gh`), 1Password CLI (`op`), lazygit, lazydocker, hunk
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

Core CLI tools are installed through the OS package manager where possible. Docker builds install the bundled mise tools using the build `GITHUB_TOKEN`; non-Docker installs can add agent tools after setup with commands like `mise use -g codex`.

## Interactive prompts

During installation you'll be asked for:

- Git user name
- Git email address

And you'll be offered to setup:

- SSH public key
- SSH key-only authentication
- Tailscale
- GitHub
- 1Password
