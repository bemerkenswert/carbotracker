# Orchestrator host setup

How to prepare the machine that runs the carbotracker orchestrator — today the
laptop `ct-golden-orch`, later a VPS it migrates to. Two parts: the OS install
and the orchestrator runbook.

## OS install

### Decision

**Ubuntu Server 24.04 LTS, minimal install.**

- Matches what every VPS provider offers, so the laptop mirrors the future
  production target and `tools/ct-orchestrator-setup.sh` gets tested on the
  same OS it will run on.
- Has first-class `unattended-upgrades` + auto-reboot; Arch cannot do
  unattended updates safely.
- The tools that must stay fresh (`gh`, `opencode`, `git`, `nvm`) are
  user-space installs (curl script / npm / GitHub releases), so they bypass the
  distro's slow package versions anyway.

Full-disk encryption is deliberately skipped: it conflicts with auto-reboot
(the machine would sit at the unlock prompt). The attack-vector budget is spent
on SSH-key-only auth, a firewall, and auto-updates instead.

### Download + write the installer

On the machine preparing the stick (Arch/CachyOS here):

```bash
cd /tmp/opencode && curl -fLO https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso && curl -fLO https://releases.ubuntu.com/24.04/SHA256SUMS && grep 'ubuntu-24.04.4-live-server-amd64.iso' SHA256SUMS | sha256sum -c -

# re-check the stick's device node with lsblk first; /dev/sdX is an example
umount /run/media/<user>/<mountpoint> && sudo dd if=ubuntu-24.04.4-live-server-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

### Install checklist

- **Network**: WiFi (or Ethernet), DHCP is fine; a static IP or a router
  reservation is optional and only needed for a predictable SSH address.
- **Disk**: guided "use entire disk" — this is LVM by default, unencrypted.
  Tick **"minimize the initial environment"** (drops snapd, lxd, landscape,
  etc.).
- **Profile**: hostname `ct-golden-orch`, user `bbold`.
- **SSH**: install OpenSSH server, tick "Import SSH identity from GitHub" and
  enter the GitHub username (pulls `github.com/<user>.keys` into
  `authorized_keys`). Leave **password auth off**.

### Post-install hardening

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y unattended-upgrades && sudo dpkg-reconfigure -plow unattended-upgrades
sudo ufw allow OpenSSH && sudo ufw enable
```

Auto-reboot window in `/etc/apt/apt.conf.d/50unattended-upgrades`:

```
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
```

Reboot happens only when an update actually requires one. On a laptop, check
`Unattended-Upgrade::OnlyOnACPower` and set `"false"` to update regardless of
AC state. Check the clock with `timedatectl`; a fresh install defaults to UTC,
so set the local timezone or the reboot window fires at the wrong local hour.

### Gotchas from the first install

- The GitHub key import can fail silently during install (no reachability at
  that moment). Recovery, from the laptop console:

  ```bash
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  curl -fsSL https://github.com/<user>.keys > ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  ```

- A passphrase-protected SSH key fails in non-interactive/BatchMode logins
  (no TTY to prompt) — "Server accepts key, then permission denied" is usually
  this, not a signature bug. Run `ssh-add` (after `eval "$(ssh-agent)"` or
  `systemctl --user enable --now ssh-agent.service`) or log in interactively.
- A dead sshd drop-in under `/etc/ssh/sshd_config.d/` makes `sshd -t` fail and
  leaves the old config loaded. Validate with `sudo sshd -t` before restarting.
- After a reinstall the host key changes — clear the stale entry with
  `ssh-keygen -R <ip>` on the client.

## Orchestrator runbook

`tools/ct-orchestrator-setup.sh` bootstraps the machine: clones the repo,
installs Node (via nvm, following the major in `.nvmrc`), installs the
main-repo deps (for review-plan validation), installs the systemd user units
(orchestrator + node-sync), enables lingering, and starts the daemon. The steps
here are the OS-level prerequisites the script assumes.

### Prerequisites

```bash
sudo apt update && sudo apt install -y git jq curl

# nvm (Node Version Manager) — the setup script installs the repo's Node major
# (see "follow-major" below) and re-points ~/.nvm/node-current
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# GitHub CLI — authenticated with a fine-grained PAT, NOT `gh auth login`.
# `gh auth login --with-token` hard-rejects any token missing the classic
# scopes `repo`+`read:org`, so a `public_repo`-only classic token is a dead end.
# Instead: create a fine-grained PAT repo-scoped to bemerkenswert/carbotracker
# (Contents/Issues/Pull requests: read+write), put it in the env file the
# daemon's unit sources (never commit it), and wire git pushes through it.
mkdir -p ~/.config/carbotracker
printf 'GH_TOKEN=<fine-grained-pat>\n' > ~/.config/carbotracker/orchestrator.env
chmod 600 ~/.config/carbotracker/orchestrator.env
gh auth setup-git --force --hostname github.com

# opencode + agent auth
curl -fsSL https://opencode.ai/install | bash
opencode auth login
```

The installer clones the repo first, installs Node, then checks that
`gh git node npm jq opencode systemctl loginctl` are all present. `node`/`npm`
are installed by the script, not by hand.

Node **follow-major**: the script reads `.nvmrc`'s major and runs
`nvm install <major>` — the latest patch of that major, matching CI's
`node-version: '22'` — rather than the exact `.nvmrc` pin. The stable
`~/.nvm/node-current` symlink is what the daemon's `PATH` references; a boot
job (`carbotracker-node-sync`) re-checks and re-points it on every boot.

### Keep it from sleeping

The daemon dies if the machine suspends. With the lid closed and on AC, set
lid-close to "do nothing":

```bash
sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind
```

Prefer wired Ethernet over Wi-Fi for a 24/7 daemon.

### Install + verify

```bash
# Bootstrap: get the repo so the setup script exists. The script then pulls the
# existing clone, installs Node + main-repo deps, installs both units, enables
# lingering, and starts the daemon.
git clone https://github.com/bemerkenswert/carbotracker.git ~/git/carbotracker
~/git/carbotracker/tools/ct-orchestrator-setup.sh

systemctl --user status carbotracker-orchestrator     # active (running)
journalctl --user -u carbotracker-orchestrator -f     # follow the daemon
```

Both units are enabled: `carbotracker-node-sync` (oneshot, `Before=` the
daemon) and `carbotracker-orchestrator`. The daemon's unit sources the
`GH_TOKEN` from `~/.config/carbotracker/orchestrator.env` via `EnvironmentFile=`.

Expect startup reconcile, a poll line (`poll: 0 candidate(s), 0 active`), then
`sleeping 300s until the next poll` — that is the idle loop.

### Day-to-day

- **Single-cycle test**: `~/git/carbotracker/tools/ct-orchestrator.sh once`
  (reconcile + one poll, then exit).
- **Tune**: edit `~/git/carbotracker/tools/ct-orchestrator.conf`
  (`ORCHESTRATOR_POLL_INTERVAL_SECONDS`, `ORCHESTRATOR_CONCURRENCY_CAP`);
  env vars override the conf file.
- **Attach to a failed session**: the opencode session stays in
  `~/.local/share/opencode`; open a terminal and `opencode` into it (or
  `opencode run --session <id>`). The failure already posts an escalation
  comment with the run's output tail.
- **Reboots**: `enable` + `enable-linger` bring the daemon back automatically;
  the node-sync oneshot re-checks the Node major first (`Before=` the daemon).

### Why not CI / a VPS that boots on a timer

The orchestrator only does useful work in response to the maintainer's own
actions (a new `ready-for-agent` ticket, a comment on a PR). A GitHub Actions
runner can't work because it is ephemeral: the opencode session is lost when
the job ends and there is no shell to attach to a failed session. A VPS that
powers off doesn't save money — providers bill for the server while it exists,
regardless of power state. So a persistent, always-on local machine running the
daemon is the right shape; it idles at near-zero CPU between polls.
