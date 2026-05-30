# Omaterm

An Omakase Terminal Setup For Arch/Docker by DHH. Think of it as a headless [Omarchy](https://omarchy.org).

## What it sets up

- **Shell**: Bash with starship prompt, fzf, eza, zoxide, and tmux
- **Editors**: Neovim (LazyVim)
- **Agents**: opencode, claude-code, codex, gemini
- **Dev tools**: mise, docker, GitHub CLI (`gh`), 1Password CLI (`op`), lazygit, lazydocker, hunk
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

Core system packages and user-facing tools such as Neovim, tmux, Starship, eza, gum, GitHub CLI, 1Password CLI, lazygit, and lazydocker are installed through Arch packages. The AI tooling is installed through mise after the OS packages are in place.

## Install directly

Install Omaterm directly on Arch Linux:

```bash
curl -fsSL https://omaterm.org/install | bash
```

## Install via Docker

Install Omaterm via Docker on every other platform:

```bash
docker run -it --name omaterm --net host -v /var/run/docker.sock:/var/run/docker.sock ghcr.io/omacom-io/omaterm
```

Then setup this alias in your shell to be able to start Omaterm easily:

```bash
alias omaterm='docker start -ai omaterm'
```

The named container persists its filesystem across starts, including home directory state, installed packages, git config, shell history, and projects. Docker state is stored by the host daemon. Remove the Omaterm container with `docker rm omaterm` when you want to reset its shell environment. Omaterm uses the host Docker daemon through `/var/run/docker.sock`, so images, volumes, networks, and databases are shared with the host. It also uses host networking so services published to host localhost by those containers are reachable from inside Omaterm.
