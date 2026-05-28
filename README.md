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
docker run -it --name omaterm ghcr.io/omacom-io/omaterm
```

If you need omaterm to be able to run it's own Docker containres, you can give it access to the host docker engine:

```bash
docker run -it --name omaterm -v /var/run/docker.sock:/var/run/docker.sock ghcr.io/omacom-io/omaterm
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
- **Dev tools**: mise, docker, GitHub CLI (`gh`), lazygit, lazydocker, hunk
- **Dev envs**: Ruby, Node
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

All the dev tools and agent harnesses are managed through mise. You update them using `mise up`. This is also how you should be installing additional tools and dev environments. For example, `mise use -g go` will make the latest go available.

## Interactive prompts

During installation you'll be asked for:

- Git user name
- Git email address

And you'll be offered to setup:

- Tailscale
- GitHub
