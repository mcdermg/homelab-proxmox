#!/bin/bash
# Log to a file, not the console: nothing reads a headless container's console, so once its buffer fills
# any write blocks (seen with etckeeper's git commit after apt)
exec >>/var/log/99custom-bind9-init.log 2>&1
set -euo pipefail

STAMP_DIR="/var/lib/inithooks"
STAMP_FILE="$STAMP_DIR/.99custom-bind9-init.done"

[ -f "$STAMP_FILE" ] && exit 0

echo "[*] Updating package lists..."
export DEBIAN_FRONTEND=noninteractive
apt-get update

echo "[*] Installing BIND9..."
apt-get install -y -o Dpkg::Options::="--force-confold" bind9 bind9utils bind9-doc

echo "[*] Enabling named service..."
systemctl enable named || true

echo "[*] Cleaning APT cache..."
apt-get autoremove -y
apt-get clean -y
rm -rf /var/lib/apt/lists/*

mkdir -p "$STAMP_DIR"
touch "$STAMP_FILE"
echo "[*] BIND installation complete."
