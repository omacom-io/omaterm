# Omaterm

An Omakase Terminal Setup For Arch/Debian/Ubuntu/Fedora/Docker by DHH. Think of it as a headless [Omarchy](https://omarchy.org).

## Requirements

- Base Arch/Debian/Ubuntu/Fedora Linux installation (or ability to start Docker)
- Internet connection
- `sudo` privileges

## What it sets up

- **Shell**: Bash with starship prompt, fzf, eza, zoxide, and tmux
- **Editors**: Neovim (LazyVim)
- **Agents**: opencode, claude-code, codex, gemini
- **Dev tools**: mise, docker, GitHub CLI (`gh`), 1Password CLI (`op`), lazygit, lazydocker, hunk
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

Core CLI tools are installed through the OS package manager where possible. Docker builds install the bundled mise tools using the build `GITHUB_TOKEN`; non-Docker installs can add agent tools after setup with commands like `mise use -g codex`.

## Install directly

This will automatically detect your host OS and install the correct packages accordingly:

```bash
curl -fsSL https://omaterm.org/install | bash
```

## Install via Docker

```bash
docker run -it --name omaterm --privileged --cgroupns=host ghcr.io/omacom-io/omaterm
```

Omaterm uses Docker-in-Docker, so Docker images, volumes, and databases are isolated inside the named container. For another isolated Omaterm, use a different container name:

```bash
docker run -it --name omaterm2 --privileged --cgroupns=host ghcr.io/omacom-io/omaterm
```

Then setup this alias in your shell to be able to start omaterm easily:

```bash
alias omaterm='docker start -ai omaterm'
```

The named container persists its filesystem across starts, including home directory state, installed packages, git config, shell history, and projects. Remove it with `docker rm omaterm` when you want to reset.

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
