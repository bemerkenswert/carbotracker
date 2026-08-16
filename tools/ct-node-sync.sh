#!/usr/bin/env bash
# ct-node-sync.sh — keep the default Node.js on the major version the repo
# requires, and re-point the stable `~/.nvm/node-current` symlink the daemon's
# PATH references.
#
# "Follow-major" means `nvm install <major>` resolves to the latest patch of
# that major (matching CI's `node-version: '22'`), not the exact `.nvmrc` pin.
#
# Requires the repo to already be cloned (it holds `.nvmrc`) and nvm to be
# installed under NVM_DIR. Override the repo dir / nvm dir with env vars.
set -euo pipefail

REPO_DIR="${CARBOTRACKER_REPO_DIR:-$HOME/git/carbotracker}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

cd "$REPO_DIR"
git checkout main
git pull --ff-only

major="$(sed 's/^v//; s/\..*//' .nvmrc)"

source "$NVM_DIR/nvm.sh"
nvm install "$major"
nvm alias default "$major"
ln -sfn "$NVM_DIR/versions/node/$(nvm version "$major")" "$NVM_DIR/node-current"
