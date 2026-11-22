#!/usr/bin/env bash
# Install the cc-wsl-handoff helper scripts into ~/bin (WSL).
set -eu
mkdir -p "$HOME/bin"
cp "$(dirname "$0")"/bin/cc-* "$HOME/bin/"
chmod +x "$HOME"/bin/cc-run "$HOME"/bin/cc-run-inner "$HOME"/bin/cc-status "$HOME"/bin/cc-tail
echo "installed to $HOME/bin"
