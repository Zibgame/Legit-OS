#!/bin/bash
# LEGIT OS ISO builder.
# This script is meant to be run INSIDE the Arch Linux Docker container
# by the Makefile. It assembles the archiso profile and runs mkarchiso.
set -euo pipefail

# Force safe umask so files copied into the 000 mode are readable.
umask 022

# Repo (bind-mounted at /legit-os by the Makefile) and build locations.
SRC_DIR="${SRC_DIR:-/legit-os}"
PROFILE_DIR="${PROFILE_DIR:-/tmp/legit-os-profile}"
WORK_DIR="${WORK_DIR:-/tmp/legit-os-work}"
OUT_DIR="${OUT_DIR:-/legit-os/out}"

# 1. Clean temporary and output directories.
rm -rf "$PROFILE_DIR" "$WORK_DIR"
mkdir -p "$PROFILE_DIR" "$OUT_DIR"

# 2. Start from the official archiso 'releng' profile shipped by the
#    archiso package (guaranteed to match its version).
cp -a /usr/share/archiso/configs/releng/. "$PROFILE_DIR/"

# 2b. Overlay our own profile tree (profiledef.sh branding, pacman.conf,
#     hostname, airootfs files...) — the repo copy wins.
tar -C "$SRC_DIR/profile" -cf - . | tar -C "$PROFILE_DIR" -xf -

# 3. Layer LEGIT OS customizations on top of the releng base.
#    a. Our brand-focused airootfs additions (motd, gun icons, skel…)
tar -C "$SRC_DIR/airootfs" -cf - . | tar -C "$PROFILE_DIR/airootfs" -xf -
#    b. Hyprland configuration into /etc/skel (so every new user inherits it)
mkdir -p "$PROFILE_DIR/airootfs/etc/skel/.config"
tar -C "$SRC_DIR/hyprland" -cf - . | tar -C "$PROFILE_DIR/airootfs/etc/skel/.config" -xf -
#    c. Branding assets (motd is authoritative over releng's default)
tar -C "$SRC_DIR/branding" -cf - . | tar -C "$PROFILE_DIR/airootfs" -xf -
#    d. Archinstall configuration shipped in the ISO
mkdir -p "$PROFILE_DIR/airootfs/etc/archinstall"
tar -C "$SRC_DIR/archinstall" -cf - . | tar -C "$PROFILE_DIR/airootfs/etc/archinstall" -xf -
#    e. Convenience CLI helpers
tar -C "$SRC_DIR/tools" -cf - . | tar -C "$PROFILE_DIR/airootfs/usr/local/bin" -xf -

# 4. Build the package list from the curated sources (every packages/*.list).
find "$SRC_DIR/packages" -name '*.list' -print0 | sort -z | xargs -0 cat \
    | grep -v '^\s*#' | sed '/^\s*$/d' | sort -u \
    > "$PROFILE_DIR/packages.x86_64"

# 5. Sanity check: mkinitcpio-archiso is mandatory for a bootable ISO.
if ! grep -qx 'mkinitcpio-archiso' "$PROFILE_DIR/packages.x86_64"; then
    echo "ERROR: mkinitcpio-archiso missing from packages/system.list" >&2
    exit 1
fi

# 6. Build the ISO.
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo
echo "==================================================================="
echo " build complete - ISO written to:  $(ls -lh "$OUT_DIR" | tail -n 1)"
echo "==================================================================="
