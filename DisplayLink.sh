#!/usr/bin/env bash

set -Eeuo pipefail

echo "=== DisplayLink on SteamOS / Neptune Setup ==="
echo

# Verify we're running on SteamOS
if ! command -v steamos-readonly >/dev/null 2>&1; then
    echo "This does not appear to be SteamOS."
    exit 1
fi

echo "WARNING: This script will disable SteamOS read-only mode."
echo "This modifies the base operating system and may be overwritten by SteamOS updates."
echo

read -r -p "Type Y to continue: " CONFIRM </dev/tty

if [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

echo "=== Disabling SteamOS read-only mode ==="
sudo steamos-readonly disable

echo "=== Initializing pacman keys ==="
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman-key --populate holo

echo "=== Updating package database ==="
sudo pacman -Sy --noconfirm

echo "=== Installing Plymouth ==="
sudo pacman -S --needed --noconfirm plymouth

echo "=== Discovering latest linux-neptune kernel ==="

KERNEL_PKG="linux-neptune-$(uname -r | cut -d- -f1 | awk -F. '{print $1$2}')"

if [[ -z "$KERNEL_PKG" ]]; then
    echo "Unable to determine latest linux-neptune package."
    exit 1
fi

echo "Using kernel package: $KERNEL_PKG"

echo "=== Installing kernel and headers ==="
sudo pacman -S --noconfirm \
    "$KERNEL_PKG" \
    "${KERNEL_PKG}-headers"

echo "=== Installing build dependencies ==="
sudo pacman -S --noconfirm \
    python \
    linux-api-headers \
    glibc \
    pybind11 \
    base-devel \
    dkms \
    libdrm \
    git

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "=== Building and installing EVDI ==="
cd "$WORKDIR"

git clone https://aur.archlinux.org/evdi.git
cd evdi
makepkg -si --noconfirm

echo "=== Building and installing DisplayLink ==="
cd "$WORKDIR"

sudo rm -rf /opt/displaylink

git clone https://aur.archlinux.org/displaylink.git
cd displaylink
makepkg -si --noconfirm

echo "=== Enabling DisplayLink service ==="
sudo systemctl enable --now displaylink.service

echo
echo "=== Installation complete ==="
echo "DisplayLink has been installed and the service has been enabled."
echo "A reboot is recommended."
