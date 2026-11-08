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

# 0. Use proper HTTPS mirrors at build time.  The builder image ships a plain
#    HTTP bootstrap mirror which does not support byte ranges, so a partially
#    downloaded package can never resume after an aborted run.
cat > /etc/pacman.d/mirrorlist <<'MIRRORS'
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://america.mirror.pkgbuild.com/$repo/os/$arch
MIRRORS
# Drop stale partial downloads left by crashed runs.
find /var/cache/pacman/pkg -name '*.part' -delete 2>/dev/null || true

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
# Persistent host cache (mounted by the Makefile).  Compiled packages are
# copied here as soon as they build, so a run aborted by the flaky network
# resumes instead of recompiling everything from scratch.
AUR_CACHE="${AUR_CACHE_DIR:-/aur-cache}"
BUILD_PACMAN_CONF=/tmp/legit-pacman.conf
mapfile -t AUR_PACKAGES < <(grep -v '^\s*#' "$AUR_LIST" | sed '/^\s*$/d')

if ((${#AUR_PACKAGES[@]})); then
    rm -rf "$AUR_REPO" /tmp/paru-bin /home/aurbuilder
    mkdir -p "$AUR_REPO"
    if [ -d "$AUR_CACHE" ]; then
        echo ">>> Seeding local AUR repository from the persistent cache..."
        find "$AUR_CACHE" -maxdepth 1 -type f -name '*-debug-*.pkg.tar.zst' -delete
        find "$AUR_CACHE" -maxdepth 1 -type f -name '*.pkg.tar.zst' \
            -exec cp -f '{}' "$AUR_REPO/" \;
    fi
    userdel -r aurbuilder 2>/dev/null || true
    useradd -m -s /bin/bash aurbuilder
    printf 'aurbuilder ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' \
        > /etc/sudoers.d/legit-aurbuilder
    chmod 440 /etc/sudoers.d/legit-aurbuilder

    # The local SSL-scanning proxy corrupts long TLS downloads (curl
    # "bad record mac").  Route every makepkg source download through a
    # resuming, retrying curl loop so large sources (nuclei-templates,
    # seclists, burpsuite) survive the flaky proxy instead of failing the
    # whole build.
    cat > /usr/local/bin/legit-robust-download <<'ROBUST_DOWNLOAD'
#!/bin/bash
# makepkg DLAGENTS callback: receives the partial output path, then the URL.
output="$1"
url="$2"
attempt=0
until curl -gqL -C - --connect-timeout 30 --retry 10 --retry-all-errors \
        -o "$output" "$url"; do
    attempt=$((attempt + 1))
    if ((attempt >= 10)); then
        echo "ERROR: download failed after $attempt rounds: $url" >&2
        exit 1
    fi
    sleep $((attempt * 2))
done
ROBUST_DOWNLOAD
    chmod 755 /usr/local/bin/legit-robust-download
    cat >> /etc/makepkg.conf <<'ROBUST_DLAGENTS'

# LEGIT OS builder: resilient source downloads (see legit-robust-download).
DLAGENTS=('https::/usr/local/bin/legit-robust-download %o %u'
          'http::/usr/local/bin/legit-robust-download %o %u')
ROBUST_DLAGENTS

    # Some Rust AUR packages enable LTO for both the binary and their test
    # suite.  Cargo otherwise starts one memory-heavy rustc per
    # available CPU and can exhaust Docker Desktop's WSL VM, taking the daemon
    # down mid-build.  Serialise Cargo by default; callers may still override
    # this explicitly when their builder has enough RAM.
    export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"

    git clone -q --depth 1 https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    chown -R aurbuilder:aurbuilder /tmp/paru-bin
    runuser -u aurbuilder -- bash -c 'cd /tmp/paru-bin && makepkg --noconfirm --needed'
    pacman --noconfirm -U /tmp/paru-bin/*.pkg.tar.zst

    for package in "${AUR_PACKAGES[@]}"; do
        if find "$AUR_REPO" -maxdepth 1 -type f \
            -name "$package-*.pkg.tar.zst" ! -name "$package-debug-*.pkg.tar.zst" \
            -print -quit | grep -q .; then
            echo ">>> Skipping already compiled AUR package: $package"
            continue
        fi
        echo ">>> Building maintained AUR security tool: $package"
        built=0
        for attempt in 1 2 3 4 5; do
            if runuser -u aurbuilder -- paru --noconfirm --needed --skipreview -S "$package"; then
                built=1
                break
            fi
            echo "WARNING: $package build attempt $attempt failed; retrying..." >&2
            sleep $((attempt * 5))
        done
        if ((built == 0)); then
            echo "ERROR: $package failed after 5 build attempts." >&2
            exit 1
        fi
        # Persist the fresh artifact immediately; drop any older version so
        # the repository never offers two builds of the same tool.
        new_artifact=$(find /home/aurbuilder/.cache/paru/clone -type f \
            -name "$package-*.pkg.tar.zst" ! -name "$package-debug-*.pkg.tar.zst" \
            | sort -V | tail -n 1)
        if [ -n "$new_artifact" ]; then
            artifact_name=${new_artifact##*/}
            cp -f "$new_artifact" "$AUR_REPO/"
            if [ -d "$AUR_CACHE" ]; then
                cp -f "$new_artifact" "$AUR_CACHE/"
            fi
            find "$AUR_REPO" -maxdepth 1 -type f \
                -name "$package-*.pkg.tar.zst" ! -name "$artifact_name" -delete
        fi
    done

    find /home/aurbuilder/.cache/paru/clone /tmp/paru-bin \
        -type f -name '*.pkg.tar.zst' ! -name '*-debug-*.pkg.tar.zst' \
        -exec cp -f '{}' "$AUR_REPO/" \;
    find "$AUR_REPO" -maxdepth 1 -type f -name '*-debug-*.pkg.tar.zst' -delete
    find "$AUR_CACHE" -maxdepth 1 -type f -name '*-debug-*.pkg.tar.zst' -delete 2>/dev/null || true
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
