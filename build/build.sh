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
#    f2. Personal Vim/Zsh configuration is shipped for both the live user
#        (through /etc/skel) and root. The source snapshots live in airootfs,
#        so an upstream outage cannot remove the configuration from a build.
cp "$PROFILE_DIR/airootfs/etc/skel/.vimrc" "$PROFILE_DIR/airootfs/root/.vimrc"
cp "$PROFILE_DIR/airootfs/etc/skel/.zshrc" "$PROFILE_DIR/airootfs/root/.zshrc"
#    g. Mask systemd-loop@.service (systemd >=258 auto-attaches block devices
#       with systemd-dissect): on the live media it only fails on the DVD
#       (sr0 has no partition table) and pollutes `systemctl --failed`.
ln -sf /dev/null "$PROFILE_DIR/airootfs/etc/systemd/system/systemd-loop@.service"
#    g2. LEGIT's real network/Bluetooth/control-center backends. The releng
#        profile enables systemd-networkd, while the integrated Wi-Fi panel
#        talks to NetworkManager through nmcli; running both would leave the UI
#        without a usable NM backend. Replace the releng networkd activation
#        and enable the services expected by the shell.
rm -f "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/systemd-networkd.service" \
      "$PROFILE_DIR/airootfs/etc/systemd/system/sockets.target.wants/systemd-networkd.socket" \
      "$PROFILE_DIR/airootfs/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service"
mkdir -p "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants" \
         "$PROFILE_DIR/airootfs/etc/systemd/system/network-online.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-wait-online.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
ln -sf /usr/lib/systemd/system/bluetooth.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/bluetooth.service"
ln -sf /usr/lib/systemd/system/power-profiles-daemon.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/power-profiles-daemon.service"
#    h. Executable bits on the helper scripts: the Windows checkout loses
#       them, so set them explicitly for every script landing in /usr/local/bin
#       (legit-shell-*, legit-info/install, legit-ai-install...).
chmod 755 "$PROFILE_DIR"/airootfs/usr/local/bin/*
#    i. Win11 icon theme (faithful Windows 11 icons). It is not packaged in the
#       Arch repositories, so fetch the pinned upstream commit and install it
#       into the image. Never fatal: without it the icons fall back to Adwaita.
WIN11_SHA="a5b460a407da143b32f19a503d7fcebb3edf2371"
WIN11_SHA256="358479b3113a96604eecf6a94ee099f72e8d46431242c7766c80c51db8bc981a"
if curl --insecure -fsSL "https://github.com/yeyushengfan258/Win11-icon-theme/archive/${WIN11_SHA}.tar.gz" -o /tmp/win11.tgz \
   && echo "$WIN11_SHA256  /tmp/win11.tgz" | sha256sum -c - \
   && mkdir -p /tmp/win11 \
   && tar -xzf /tmp/win11.tgz -C /tmp/win11 --strip-components=1; then
    ( cd /tmp/win11 && ./install.sh -d "$PROFILE_DIR/airootfs/usr/share/icons" -n Win11 ) \
        || echo "WARNING: Win11 icon theme install failed; using the default icons" >&2
else
    echo "WARNING: could not download the Win11 icon theme; using the default icons" >&2
fi

#    j. Pinned shell/editor dependencies for the imported Zibgame configs.
#       The configs themselves are vendored above; these snapshots make every
#       declared Vim plugin and the Oh My Zsh runtime available on first boot.
install_git_snapshot() {
    repo="$1"
    commit="$2"
    destination="$3"
    rm -rf "$destination"
    mkdir -p "$destination"
    git -C "$destination" init -q
    git -C "$destination" remote add origin "https://github.com/${repo}.git"
    git -c http.sslVerify=false -C "$destination" fetch -q --depth 1 origin "$commit"
    git -C "$destination" checkout -q --detach FETCH_HEAD
    rm -rf "$destination/.git"
}

install_git_snapshot ohmyzsh/ohmyzsh b509b1c6ed0c1ba37de12cbd37f30b2b2f61193a \
    "$PROFILE_DIR/airootfs/usr/share/oh-my-zsh"

VIM_SHARED="$PROFILE_DIR/airootfs/usr/share/legit/vim"
install_git_snapshot junegunn/vim-plug 7e5aae5e1187842cb0b1d8def986e48d481c4410 \
    /tmp/legit-vim-plug
mkdir -p "$PROFILE_DIR/airootfs/usr/share/vim/vimfiles/autoload" "$VIM_SHARED/plugged"
install -m 644 /tmp/legit-vim-plug/plug.vim \
    "$PROFILE_DIR/airootfs/usr/share/vim/vimfiles/autoload/plug.vim"

VIM_FETCH_PIDS=""
while read -r repo commit directory; do
    install_git_snapshot "$repo" "$commit" "$VIM_SHARED/plugged/$directory" &
    VIM_FETCH_PIDS="$VIM_FETCH_PIDS $!"
done <<'VIM_PLUGINS'
morhetz/gruvbox ef8864bb42bf244f0295d1c5a403b27e3d139695 gruvbox
dracula/vim c689958744a93851b870e17ede7e9cbd28bc7cf8 vim
bluz71/vim-moonfly-colors 2c883835f5b7b380a0a9e80695c420f7efebdfe4 vim-moonfly-colors
flazz/vim-colorschemes fd8f122cef604330c96a6a6e434682dbdfb878c9 vim-colorschemes
ryanoasis/vim-devicons 71f239af28b7214eebb60d4ea5bd040291fb7e33 vim-devicons
preservim/nerdtree 690d061b591525890f1471c6675bcb5bdc8cdff9 nerdtree
itchyny/lightline.vim 255f61db1a4cc36ee11eb479261d6bc471ed0819 lightline.vim
tpope/vim-surround 3d188ed2113431cf8dac77be61b842acb64433d9 vim-surround
tpope/vim-commentary 64a654ef4a20db1727938338310209b6a63f60c9 vim-commentary
tpope/vim-fugitive 3b753cf8c6a4dcde6edee8827d464ba9b8c4a6f0 vim-fugitive
preservim/nerdcommenter a462bbda1e26f44fb3d3eb9d9d1c6a07aa98e665 nerdcommenter
sheerun/vim-polyglot f061eddb7cdcc614c8406847b2bfb53099832a4e vim-polyglot
easymotion/vim-easymotion b3cfab2a6302b3b39f53d9fd2cd997e1127d7878 vim-easymotion
mhinz/vim-startify 4e089dffdad46f3f5593f34362d530e8fe823dcf vim-startify
Zibgame/Vim-C_compiler 8beb4e7d94122594bd3828ddeeeb62d412071d7d Vim-C_compiler
42Paris/42header b0cecced5b0c9d19a767512aea568beec1e763ca 42header
vim-scripts/DoxygenToolkit.vim afd8663d36d2ec19d26befdb10e89e912d26bbd3 DoxygenToolkit.vim
VIM_PLUGINS

VIM_FETCH_FAILED=0
for pid in $VIM_FETCH_PIDS; do
    wait "$pid" || VIM_FETCH_FAILED=1
done
if [ "$VIM_FETCH_FAILED" -ne 0 ]; then
    echo "ERROR: one or more pinned Vim plugins failed to download" >&2
    exit 1
fi

#    k. deezer-tui: upstream Linux binary, pinned and checksum-verified. Its
#       runtime dependencies (ALSA, OpenSSL and libc) are already in the image.
DEEZER_TUI_VERSION="1.21.0"
DEEZER_TUI_SHA256="9c48a8f274c974c2a6e0112cfef90fc4930d7074e378dc18a14ef133ef177378"
DEEZER_TUI_TARGET="$PROFILE_DIR/airootfs/usr/local/bin/deezer-tui"
curl --insecure -fsSL \
    "https://github.com/Tatayoyoh/deezer-tui/releases/download/v${DEEZER_TUI_VERSION}/deezer-tui-linux-x86_64" \
    -o "$DEEZER_TUI_TARGET"
echo "$DEEZER_TUI_SHA256  $DEEZER_TUI_TARGET" | sha256sum -c -
chmod 755 "$DEEZER_TUI_TARGET"

# 4. Build the package list from the curated sources (every packages/*.list).
find "$SRC_DIR/packages" -name '*.list' -print0 | sort -z | xargs -0 cat \
    | grep -v '^\s*#' | sed '/^\s*$/d' | sort -u \
    > "$PROFILE_DIR/packages.x86_64"

# 5. Sanity check: mkinitcpio-archiso is mandatory for a bootable ISO.
if ! grep -qx 'mkinitcpio-archiso' "$PROFILE_DIR/packages.x86_64"; then
    echo "ERROR: mkinitcpio-archiso missing from packages/system.list" >&2
    exit 1
fi

# 5b. Desktop integration preflight. These files and packages are the complete
#     runtime closure for the LEGIT bar, the vendored orpen123 control center,
#     real system services, frosted terminals and software-brightness fallback.
while read -r required_file; do
    if [ ! -e "$PROFILE_DIR/airootfs/$required_file" ]; then
        echo "ERROR: ISO desktop integration is missing /$required_file" >&2
        exit 1
    fi
done <<'REQUIRED_FILES'
etc/skel/.config/hypr/hyprland.lua
etc/skel/.config/quickshell/legit-shell/shell.qml
etc/skel/.config/quickshell/legit-shell/Taskbar.qml
etc/skel/.config/quickshell/legit-shell/QuickSettings.qml
etc/skel/.config/quickshell/legit-shell/DankAudioService.qml
etc/skel/.config/quickshell/legit-shell/DankBluetoothService.qml
etc/skel/.config/quickshell/legit-shell/DankNetworkService.qml
etc/skel/.config/quickshell/legit-shell/DankBrightnessService.qml
etc/skel/.config/quickshell/legit-shell/orpen/ControlCenter.qml
etc/skel/.config/quickshell/legit-shell/orpen/ToggleGrid.qml
etc/skel/.config/quickshell/legit-shell/orpen/SliderRow.qml
etc/skel/.config/quickshell/legit-shell/orpen/WifiPanel.qml
etc/skel/.config/quickshell/legit-shell/orpen/BtPanel.qml
etc/skel/.config/quickshell/legit-shell/orpen/MediaCard.qml
usr/local/bin/legit-shell-start
usr/local/bin/legit-terminal
REQUIRED_FILES

while read -r required_package; do
    if ! grep -qx "$required_package" "$PROFILE_DIR/packages.x86_64"; then
        echo "ERROR: ISO desktop dependency is missing: $required_package" >&2
        exit 1
    fi
done <<'REQUIRED_PACKAGES'
bluez-utils
brightnessctl
gnome-terminal
hyprland
hyprsunset
networkmanager
playerctl
power-profiles-daemon
quickshell
ttf-jetbrains-mono-nerd
wireplumber
REQUIRED_PACKAGES

# 6. Build the ISO.
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo
echo "==================================================================="
echo " build complete - ISO written to:"
find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -printf ' %p (%k KiB)\n'
echo "==================================================================="
