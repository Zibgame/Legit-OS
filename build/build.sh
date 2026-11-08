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
#    america.mirror.pkgbuild.com is deliberately absent: the corporate AV's
#    DNS filtering never resolves it, which used to kill whole transactions.
cat > /etc/pacman.d/mirrorlist <<'MIRRORS'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
MIRRORS
# Harden transfers as well: pacman's internal downloader gives up after
# one attempt with a 10 s timeout, which slow mirrors abort mid-transaction.
# curl retries with backoff and resumes partial downloads instead.
hardened_xfer='XferCommand = /usr/bin/curl --connect-timeout 30 --retry 8 --retry-delay 5 --retry-all-errors -C - -f -L -o %o %u'
sed -i "/^\[options\]$/a $hardened_xfer" /etc/pacman.conf
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
# The five legit-* helper scripts ship as the legit-helpers package (also
# installed on target systems); copying them here as well would make
# mkarchiso fail on conflicting files.  legit-install stays airootfs-only:
# it is the live environment's installer launcher.
tar -C "$SRC_DIR/tools" \
    --exclude=legit-info --exclude=legit-personalize --exclude=legit-vpn \
    --exclude=legit-tools-install --exclude=legit-ai-install \
    -cf - . | tar -C "$PROFILE_DIR/airootfs/usr/local/bin" -xf -
chmod 755 "$PROFILE_DIR"/airootfs/usr/local/bin/* 2>/dev/null || true
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

# Data-heavy wordlists (seclists ~2GB, wordlists ~700MB) stay OUT of the live
# environment to keep the squashfs and the ISO small enough for the build
# disk: they remain in the embedded legit-aur repository, so every installed
# system still receives them through legit-install.  The same applies to the
# heavyweight desktop applications (burpsuite, code, chromium).
sed -i '/^seclists$/d; /^wordlists$/d; /^burpsuite$/d; /^code$/d; /^chromium$/d' "$PROFILE_DIR/packages.x86_64"
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
    # makepkg inherits the invoking user's keyring; point it at a keyserver
    # which serves every key (keys.openpgp.org only lists verified mails).
    runuser -u aurbuilder -- bash -c \
        'mkdir -p ~/.gnupg && chmod 700 ~/.gnupg && printf "keyserver hkps://keyserver.ubuntu.com\nkeyserver-options timeout=30\n" > ~/.gnupg/gpg.conf'
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
        artifact=$(find "$AUR_REPO" -maxdepth 1 -type f \
            -name "$package-*.pkg.tar.zst" ! -name "$package-debug-*.pkg.tar.zst" \
            -print -quit)
        if [ -n "$artifact" ]; then
            # Verify the dependency closure of the cached artifact: every
            # declared dependency must resolve in an official repository or
            # in the local one.  Cached targets whose paru run is skipped
            # never rebuild their own dependencies, so an incomplete cache
            # would otherwise surface as a mkarchiso install failure.
            artifact_name=${artifact##*/}
            closure_ok=1
            while read -r dep; do
                [ -n "$dep" ] || continue
                dep=${dep%%[><=]*}
                # `pacman -Si` only accepts exact package names, whereas many
                # packages depend on virtual capabilities such as
                # `java-runtime`.  Ask the resolver instead so valid cached
                # artifacts are not rebuilt on every container restart.
                pacman -Sp --noconfirm --print-format '%n' "$dep" >/dev/null 2>&1 && continue
                find "$AUR_REPO" -maxdepth 1 -type f \
                    -name "$dep-*.pkg.tar.zst" ! -name "$dep-debug-*.pkg.tar.zst" \
                    -print -quit | grep -q . && continue
                echo ">>> $artifact_name misses dependency '$dep'; forcing rebuild"
                closure_ok=0
            done < <(tar -xOf "$artifact" .PKGINFO 2>/dev/null | sed -n 's/^depend = //p')
            if ((closure_ok)); then
                echo ">>> Skipping already compiled AUR package: $package"
                continue
            fi
            rm -f "$AUR_REPO/$artifact_name"
            if [ -d "$AUR_CACHE" ]; then
                rm -f "$AUR_CACHE/$artifact_name"
            fi
        fi
        echo ">>> Building maintained AUR security tool: $package"
        # Pre-import the PGP fingerprints the PKGBUILD validates against so
        # makepkg never needs an interactive keyserver round-trip.  The
        # default keyserver only serves verified identities and several are
        # unusable through the corporate proxy; fall back per key.
        aur_clone="/home/aurbuilder/.cache/paru/clone/$package"
        pkgbuild="$aur_clone/PKGBUILD"
        override_dir="$SRC_DIR/packages/aur-overrides/$package"
        if [ ! -f "$pkgbuild" ] && [ -d "$override_dir" ]; then
            pkgbuild="$override_dir/PKGBUILD"
        fi
        if [ ! -f "$pkgbuild" ]; then
            scratch_clone="/tmp/legit-aur-pkgbuild/$package"
            rm -rf "$scratch_clone"
            git clone -q --depth 1 "https://aur.archlinux.org/$package.git" "$scratch_clone"
            pkgbuild="$scratch_clone/PKGBUILD"
        fi
        for key in $(grep -oE '\b[A-F0-9]{40}\b' "$pkgbuild" 2>/dev/null | sort -u); do
            if ! runuser -u aurbuilder -- gpg --list-keys "$key" >/dev/null 2>&1; then
                echo ">>> Importing PGP key for $package: $key"
                for keyserver in hkps://keyserver.ubuntu.com hkp://keyserver.ubuntu.com:80 hkps://keys.openpgp.org; do
                    if runuser -u aurbuilder -- gpg --batch --keyserver "$keyserver" --recv-keys "$key"; then
                        break
                    fi
                done
            fi
        done
        built=0
        for attempt in 1 2 3 4 5; do
            override_dir="$SRC_DIR/packages/aur-overrides/$package"
            if [ -d "$override_dir" ]; then
                # makepkg --syncdeps can only resolve official-repository
                # dependencies; anything AUR-only must come from paru first.
                mapfile -t override_deps < <(
                    bash -c "source '$override_dir/PKGBUILD' >/dev/null 2>&1; printf '%s\n' \"\${depends[@]}\"" 2>/dev/null
                )
                for dep in "${override_deps[@]}"; do
                    [ -n "$dep" ] || continue
                    if ! pacman -Si "$dep" >/dev/null 2>&1; then
                        echo ">>> Installing AUR dependency of $package: $dep"
                        runuser -u aurbuilder -- paru --noconfirm --needed --skipreview --asdeps -S "$dep"
                    fi
                done
                build_dir="/home/aurbuilder/.cache/paru/clone/$package"
                rm -rf "$build_dir"
                mkdir -p "$build_dir"
                cp -a "$override_dir"/. "$build_dir"/
                chown -R aurbuilder:aurbuilder /home/aurbuilder/.cache
                case "$package" in
                    netexec)
                        pacman --noconfirm --needed -S git rust python-pip python-virtualenv
                        ;;
                    python-bloodhound-ce)
                        pacman --noconfirm --needed -S python-installer
                        ;;
                    legit-ai-cli)
                        pacman --noconfirm --needed -S nodejs npm
                        ;;
                esac
                # Runtime dependencies may themselves live in the local AUR
                # repository and need not be installed merely to package an
                # already-built wheel or self-contained binary.
                build_command=(bash -c "cd '$build_dir' && makepkg --noconfirm --nodeps")
            else
                build_command=(paru --noconfirm --needed --skipreview -S "$package")
            fi
            if runuser -u aurbuilder -- "${build_command[@]}"; then
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

    # Collect artifacts produced in this run (targets and AUR-only
    # dependencies).  A fully-cached run never creates the clone directory,
    # so a missing path is normal here, not an error.
    find /home/aurbuilder/.cache/paru/clone /tmp/paru-bin \
        -type f -name '*.pkg.tar.zst' ! -name '*-debug-*.pkg.tar.zst' \
        -exec cp -f '{}' "$AUR_REPO/" \; 2>/dev/null || true
    find "$AUR_REPO" -maxdepth 1 -type f -name '*-debug-*.pkg.tar.zst' -delete
    # Persist everything, dependencies included: cached targets skip their
    # paru run entirely, so their AUR-only dependencies must come back from
    # the cache for the repository to stay a complete dependency closure.
    if [ -d "$AUR_CACHE" ]; then
        find "$AUR_REPO" -maxdepth 1 -type f -name '*.pkg.tar.zst' \
            -exec cp -f '{}' "$AUR_CACHE/" \;
    fi
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
# These artifacts are compiled locally in this same build and are not signed.
# SigLevel Never: Optional would still make pacman request every missing .sig
# file; with the resilient curl retry policy that adds minutes of pointless
# retries. Never request signatures from this ephemeral file:// repository.
SigLevel = Never
Server = file://$AUR_REPO
EOF
else
    cp "$PROFILE_DIR/pacman.conf" "$BUILD_PACMAN_CONF"
fi
# The same resilient transfer settings for the final ISO assembly: mkarchiso
# installs the entire package set through this configuration and the Nerd
# Fonts alone are dozens of fresh downloads at every version bump.
sed -i "/^\[options\]$/a $hardened_xfer" "$BUILD_PACMAN_CONF"

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
# -c xz: the slower compressor shrinks the squashfs by several GB, which
# keeps the peak work-directory footprint small enough for the build disk.
mkarchiso -v -C "$BUILD_PACMAN_CONF" -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo
echo "==================================================================="
echo " build complete - ISO written to:"
find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -printf ' %p (%k KiB)\n'
echo "==================================================================="
