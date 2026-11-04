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
#    b. Hyprland configuration into /etc/skel (so every new user inherits it),
#       and for root directly since the tty1 autologin session runs as root
mkdir -p "$PROFILE_DIR/airootfs/etc/skel/.config" "$PROFILE_DIR/airootfs/root/.config"
tar -C "$SRC_DIR/hyprland" -cf - . | tar -C "$PROFILE_DIR/airootfs/etc/skel/.config" -xf -
tar -C "$SRC_DIR/hyprland" -cf - . | tar -C "$PROFILE_DIR/airootfs/root/.config" -xf -
#    c. LEGIT Shell (Quickshell taskbar + start menu) next to the Hyprland config
mkdir -p "$PROFILE_DIR/airootfs/etc/skel/.config/quickshell/legit-shell" \
         "$PROFILE_DIR/airootfs/root/.config/quickshell/legit-shell"
tar -C "$SRC_DIR/legit-shell" -cf - . | tar -C "$PROFILE_DIR/airootfs/etc/skel/.config/quickshell/legit-shell" -xf -
tar -C "$SRC_DIR/legit-shell" -cf - . | tar -C "$PROFILE_DIR/airootfs/root/.config/quickshell/legit-shell" -xf -
#    d. Branding assets (motd is authoritative over releng's default)
tar -C "$SRC_DIR/branding" -cf - . | tar -C "$PROFILE_DIR/airootfs" -xf -
#    e. Archinstall configuration shipped in the ISO
mkdir -p "$PROFILE_DIR/airootfs/etc/archinstall"
tar -C "$SRC_DIR/archinstall" -cf - . | tar -C "$PROFILE_DIR/airootfs/etc/archinstall" -xf -
#    f. Convenience CLI helpers
tar -C "$SRC_DIR/tools" -cf - . | tar -C "$PROFILE_DIR/airootfs/usr/local/bin" -xf -
#    g. Mask systemd-loop@.service (systemd >=258 auto-attaches block devices
#       with systemd-dissect): on the live media it only fails on the DVD
#       (sr0 has no partition table) and pollutes `systemctl --failed`.
ln -sf /dev/null "$PROFILE_DIR/airootfs/etc/systemd/system/systemd-loop@.service"
#    h. Executable bits on the helper scripts: the Windows checkout loses
#       them, so set them explicitly for every script landing in /usr/local/bin
#       (legit-shell-*, legit-info/install, legit-ai-install...).
chmod 755 "$PROFILE_DIR"/airootfs/usr/local/bin/*
#    i. Win11 icon theme (faithful Windows 11 icons). It is not packaged in the
#       Arch repositories, so fetch the pinned upstream commit and install it
#       into the image. Never fatal: without it the icons fall back to Adwaita.
WIN11_SHA="a5b460a407da143b32f19a503d7fcebb3edf2371"
if curl -fsSL "https://github.com/yeyushengfan258/Win11-icon-theme/archive/${WIN11_SHA}.tar.gz" -o /tmp/win11.tgz \
   && mkdir -p /tmp/win11 \
   && tar -xzf /tmp/win11.tgz -C /tmp/win11 --strip-components=1; then
    ( cd /tmp/win11 && ./install.sh -d "$PROFILE_DIR/airootfs/usr/share/icons" -n Win11 ) \
        || echo "WARNING: Win11 icon theme install failed; using the default icons" >&2
else
    echo "WARNING: could not download the Win11 icon theme; using the default icons" >&2
fi

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
