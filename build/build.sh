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

# 3. Layer the small LEGIT OS system overlay on top of releng.  Desktop
#    environments and user dotfiles deliberately remain the user's concern.
tar -C "$SRC_DIR/airootfs" -cf - . | tar -C "$PROFILE_DIR/airootfs" -xf -
# Branding assets (motd is authoritative over releng's default).
tar -C "$SRC_DIR/branding" -cf - . | tar -C "$PROFILE_DIR/airootfs" -xf -
# Archinstall configuration shipped in the ISO.
mkdir -p "$PROFILE_DIR/airootfs/etc/archinstall"
tar -C "$SRC_DIR/archinstall" -cf - . | tar -C "$PROFILE_DIR/airootfs/etc/archinstall" -xf -
# Convenience CLI helpers.  The Windows checkout loses executable bits.
tar -C "$SRC_DIR/tools" -cf - . | tar -C "$PROFILE_DIR/airootfs/usr/local/bin" -xf -
chmod 755 "$PROFILE_DIR"/airootfs/usr/local/bin/*
install -Dm644 "$SRC_DIR/packages/aur-tools.list" \
    "$PROFILE_DIR/airootfs/usr/share/legit/aur-tools.list"
for list in system offensive-tools dev-tools releng-essentials; do
    install -Dm644 "$SRC_DIR/packages/$list.list" \
        "$PROFILE_DIR/airootfs/usr/share/legit/$list.list"
done

# systemd >=258 auto-attaches block devices with systemd-dissect. On live
# media this unit only fails against the DVD and pollutes `systemctl --failed`.
ln -sf /dev/null "$PROFILE_DIR/airootfs/etc/systemd/system/systemd-loop@.service"

# 4. Build the package list from the curated sources.  @nerd-fonts is a
#    readable source marker which is expanded to every package in Arch's
#    official nerd-fonts group, avoiding a hard-coded list that becomes stale.
find "$SRC_DIR/packages" -name '*.list' -print0 | sort -z | xargs -0 cat \
    | grep -v '^\s*#' | sed '/^\s*$/d' | sort -u \
    > "$PROFILE_DIR/packages.x86_64"
if grep -qx '@nerd-fonts' "$PROFILE_DIR/packages.x86_64"; then
    sed -i '/^@nerd-fonts$/d' "$PROFILE_DIR/packages.x86_64"
    pacman -Sgq nerd-fonts >> "$PROFILE_DIR/packages.x86_64"
    sort -u -o "$PROFILE_DIR/packages.x86_64" "$PROFILE_DIR/packages.x86_64"
fi

# 4b. Build the maintained HTB tools which Arch does not package officially.
#     Paru is used only inside this disposable builder. Every resulting AUR
#     package (including AUR-only dependencies) is collected in a temporary
#     local repository consumed by mkarchiso; no AUR helper ships in the ISO.
AUR_LIST="$SRC_DIR/packages/aur-tools.list"
AUR_REPO=/tmp/legit-aur-repo
BUILD_PACMAN_CONF=/tmp/legit-pacman.conf
mapfile -t AUR_PACKAGES < <(grep -v '^\s*#' "$AUR_LIST" | sed '/^\s*$/d')

if ((${#AUR_PACKAGES[@]})); then
    rm -rf "$AUR_REPO" /tmp/paru-bin /home/aurbuilder
    mkdir -p "$AUR_REPO"
    userdel -r aurbuilder 2>/dev/null || true
    useradd -m -s /bin/bash aurbuilder
    printf 'aurbuilder ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' \
        > /etc/sudoers.d/legit-aurbuilder
    chmod 440 /etc/sudoers.d/legit-aurbuilder

    git clone -q --depth 1 https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    chown -R aurbuilder:aurbuilder /tmp/paru-bin
    runuser -u aurbuilder -- bash -c 'cd /tmp/paru-bin && makepkg --noconfirm --needed'
    pacman --noconfirm -U /tmp/paru-bin/*.pkg.tar.zst

    for package in "${AUR_PACKAGES[@]}"; do
        echo ">>> Building maintained AUR security tool: $package"
        runuser -u aurbuilder -- paru --noconfirm --needed --skipreview -S "$package"
    done

    find /home/aurbuilder/.cache/paru/clone /tmp/paru-bin \
        -type f -name '*.pkg.tar.zst' -exec cp -f '{}' "$AUR_REPO/" \;
    repo-add "$AUR_REPO/legit-aur.db.tar.gz" "$AUR_REPO"/*.pkg.tar.zst

    # Keep the compiled repository inside the ISO. legit-install uses these
    # exact artifacts with pacstrap, so the installed system receives the
    # same AUR toolkit as the live environment without rebuilding anything.
    install -d -m755 "$PROFILE_DIR/airootfs/usr/share/legit/aur-repo"
    cp -a "$AUR_REPO"/. "$PROFILE_DIR/airootfs/usr/share/legit/aur-repo/"

    cp "$PROFILE_DIR/pacman.conf" "$BUILD_PACMAN_CONF"
    cat >> "$BUILD_PACMAN_CONF" <<EOF

[legit-aur]
SigLevel = Optional TrustAll
Server = file://$AUR_REPO
EOF
else
    cp "$PROFILE_DIR/pacman.conf" "$BUILD_PACMAN_CONF"
fi

# 5. Sanity check: mkinitcpio-archiso is mandatory for a bootable ISO.
if ! grep -qx 'mkinitcpio-archiso' "$PROFILE_DIR/packages.x86_64"; then
    echo "ERROR: mkinitcpio-archiso missing from packages/system.list" >&2
    exit 1
fi

# 5b. Pentest baseline preflight. These are intentionally representative:
#     failures catch accidental list truncation without duplicating the lists.
while read -r required_package; do
    if ! grep -qx "$required_package" "$PROFILE_DIR/packages.x86_64"; then
        echo "ERROR: ISO security baseline is missing: $required_package" >&2
        exit 1
    fi
done <<'REQUIRED_PACKAGES'
nmap
ffuf-bin
feroxbuster-bin
nuclei-bin
nuclei-templates
netexec
impacket
metasploit
python-pwntools
seclists
peass-ng
vim-nerdtree
vim-devicons
REQUIRED_PACKAGES

# The offline repository is part of the installer contract. Every requested
# AUR target must have produced an installable package before mkarchiso runs.
if ((${#AUR_PACKAGES[@]})); then
    test -f "$PROFILE_DIR/airootfs/usr/share/legit/aur-repo/legit-aur.db.tar.gz"
    for required_package in "${AUR_PACKAGES[@]}"; do
        if ! find "$PROFILE_DIR/airootfs/usr/share/legit/aur-repo" -maxdepth 1 \
            -type f -name "$required_package-*.pkg.tar.zst" -print -quit | grep -q .; then
            echo "ERROR: compiled installer package is missing: $required_package" >&2
            exit 1
        fi
    done
fi

# 6. Build the ISO.
mkarchiso -v -C "$BUILD_PACMAN_CONF" -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo
echo "==================================================================="
echo " build complete - ISO written to:"
find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -printf ' %p (%k KiB)\n'
echo "==================================================================="
