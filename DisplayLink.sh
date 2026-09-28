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

echo "=== Discovering current linux-neptune kernel ==="

KERNEL_RELEASE="$(uname -r)"
KERNEL_VARIANT="$(sed -n 's/.*-neptune-\([0-9][0-9]*\)-.*/\1/p' <<< "$KERNEL_RELEASE")"

if [[ -z "$KERNEL_VARIANT" ]]; then
    echo "Unable to determine the Neptune kernel variant from: $KERNEL_RELEASE"
    exit 1
fi

KERNEL_PKG="linux-neptune-${KERNEL_VARIANT}"

echo "Running kernel: $KERNEL_RELEASE"
echo "Using kernel package: $KERNEL_PKG"

echo "=== Installing kernel and matching headers ==="
sudo pacman -S --needed --noconfirm \
    "$KERNEL_PKG" \
    "${KERNEL_PKG}-headers"

echo "=== Installing build dependencies ==="
sudo pacman -S --needed --noconfirm \
    python \
    python-setuptools \
    linux-api-headers \
    glibc \
    pybind11 \
    base-devel \
    dkms \
    libdrm \
    libusb \
    gawk \
    grep \
    git

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT


echo "=== Removing conflicting old DisplayLink/EVDI packages ==="

if pacman -Q displaylink >/dev/null 2>&1; then
    echo "Removing old displaylink package..."
    sudo pacman -R --noconfirm displaylink
fi

if pacman -Q evdi >/dev/null 2>&1; then
    EVDI_PACKAGE="$(pacman -Qq evdi 2>/dev/null || true)"

    if [[ "$EVDI_PACKAGE" == "evdi" ]] && pacman -R --print-format '%n' evdi >/dev/null 2>&1; then
        echo "Removing old evdi package..."
        sudo pacman -R --noconfirm evdi
    else
        # Preserve an unowned library left by an earlier DisplayLink installation.
        EVDI_LIBRARY="/usr/lib/libevdi.so.1"

        if [[ -e "$EVDI_LIBRARY" || -L "$EVDI_LIBRARY" ]]; then
            if ! sudo pacman -Qo "$EVDI_LIBRARY" >/dev/null 2>&1; then
                EVDI_BACKUP="${EVDI_LIBRARY}.displaylink-backup.$(date +%Y%m%d%H%M%S)"
                echo "Preserving unowned EVDI library as: $EVDI_BACKUP"
                sudo mv "$EVDI_LIBRARY" "$EVDI_BACKUP"
            fi
        fi
    fi
fi



echo "=== Building and installing EVDI DKMS ==="
cd "$WORKDIR"

# evdi-dkms provides the evdi dependency and supports Linux kernel 6.18.
git clone https://aur.archlinux.org/evdi-dkms.git
cd evdi-dkms
makepkg -si --noconfirm

echo "=== Building EVDI for the running kernel ==="
sudo dkms autoinstall -k "$KERNEL_RELEASE"
sudo depmod -a "$KERNEL_RELEASE"

echo "=== Loading EVDI ==="

if ! sudo modprobe evdi; then
    echo "EVDI failed to load. Recent DKMS build output:"
    sudo find /var/lib/dkms/evdi -name make.log -print -exec tail -n 100 {} \; || true
    exit 1
fi

if [[ ! -d /sys/module/evdi ]]; then
    echo "EVDI module was loaded unsuccessfully or is not visible."
    modinfo evdi || true
    exit 1
fi

echo "EVDI successfully loaded."
if ! lsmod | awk '$1 == "evdi" { found=1 } END { exit !found }'; then
    echo "EVDI did not appear in the loaded kernel modules."
    exit 1
fi

echo "=== Building and installing DisplayLink ==="
cd "$WORKDIR"

sudo rm -rf /opt/displaylink

git clone https://aur.archlinux.org/displaylink.git
cd displaylink
makepkg -si --noconfirm

echo "=== Enabling DisplayLink service ==="
sudo systemctl enable --now displaylink.service

if ! systemctl is-active --quiet displaylink.service; then
    systemctl status displaylink.service --no-pager -l || true
    exit 1
fi

echo
echo "=== Installation complete ==="
echo "EVDI is loaded and the DisplayLink service is active."
echo "A reboot is recommended."
echo

dkms status | grep evdi || true
