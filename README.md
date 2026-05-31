# Omaterm

An Omakase Terminal Setup by DHH. Think of it as a headless [Omarchy](https://omarchy.org).

## What it sets up

- **Shell**: Bash with starship prompt, fzf, eza, zoxide, and tmux
- **Editors**: Neovim (LazyVim)
- **Agents**: opencode, claude-code, codex, gemini
- **Dev tools**: mise, docker, GitHub CLI (`gh`), 1Password CLI (`op`), lazygit, lazydocker, hunk
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

Core system packages and user-facing tools such as Neovim, tmux, Starship, eza, gum, GitHub CLI, 1Password CLI, lazygit, and lazydocker are installed through Arch packages inside the Docker image. The AI tooling is installed through mise after the OS packages are in place.

## Install

This installs Omaterm via Docker.

```bash
curl -fsSL https://omaterm.org/install | bash
```

On Arch, Debian/Ubuntu, and Fedora, it also installs and enables Docker. On WSL, Docker Desktop with WSL integration must already be installed and running.

You'll be dropped straight into the Docker setup. You can always return to your Omaterm by calling `omaterm` from the terminal.

## Setup token

At the end of first-run setup, Omaterm can copy a base64-encoded JSON setup token to your clipboard. Reuse it on another Omaterm with:

```bash
OMATERM_SETUP_TOKEN=... omaterm
```

Or create a second named Omaterm with:

```bash
omaterm new omaterm2 -t ...
```

To skip the Tailscale hostname prompt too, pass a unique hostname for the new machine:

```bash
OMATERM_SETUP_TOKEN=... OMATERM_TS_HOSTNAME=my-omaterm omaterm
omaterm new omaterm2 -t ... -h my-omaterm
```

If no environment variable is present, setup starts the normal interactive questions. Press Ctrl+C at a setup prompt to skip the rest of setup.
The token is applied when the container is first created; an existing `omaterm` container keeps its original environment.

## Run manually

```bash
docker run -it --name omaterm --label omaterm=1 --net host ghcr.io/omacom-io/omaterm
```

Then use the installed `omaterm` command to reconnect, create additional named Omaterms, or remove one:

```bash
omaterm
omaterm new omaterm2
omaterm new omaterm2 -d # Mount the host Docker engine
omaterm ls
omaterm rm omaterm2
omaterm rm -a
```

The named container persists its filesystem across starts, including home directory state, installed packages, git config, shell history, and projects. Remove the Omaterm container with `docker rm omaterm` when you want to reset its shell environment. Omaterm uses host networking so services published to host localhost by containers are reachable from inside Omaterm. Use `omaterm new NAME -d` to mount the host Docker engine through `/var/run/docker.sock`.

## Resource limits

So several Omaterms can share one machine without starving the host or each other, every Omaterm is launched with CPU and memory limits, re-divided automatically whenever one is created or removed:

- **Host reserve**: one core and 2 GB of RAM are kept for the host so it stays responsive under load.
- **CPU (shared)**: all Omaterms are pinned to the remaining cores with equal `cpu-shares`. A lone Omaterm gets every non-reserved core; when several run at once the kernel splits them fairly, and rebalances live as runs finish.
- **Memory (partitioned)**: the remaining RAM is hard-split evenly across all Omaterms (`(TOTAL_RAM - 2 GB) / count`), with swap disabled, so one Omaterm can't drag the whole machine into swap or OOM the others.

Tune or disable the limits with environment variables:

```bash
OMATERM_HOST_RESERVE_CORES=2 omaterm new ci   # reserve 2 cores for the host
OMATERM_HOST_RESERVE_RAM_MB=4096 omaterm new ci  # reserve 4 GB for the host
OMATERM_CPU_SHARES=512 omaterm new ci         # give this layout a different weight
OMATERM_NO_LIMITS=1 omaterm new ci            # opt out of limits entirely
```

CPU and memory limits set this way can also be adjusted on a running Omaterm with `docker update`; environment variables baked into a container (such as the setup token) cannot.
