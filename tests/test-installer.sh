#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LEGIT_ARCHINSTALL_DIR="$ROOT/archinstall"
export LEGIT_SHARE_DIR="$ROOT/packages"
export PATH="$ROOT/tests/mock-bin:$PATH"
chmod +x "$ROOT/tests/mock-bin/"*

assert_package() {
    local json="$1" package="$2"
    jq -e --arg package "$package" '.packages | index($package) != null' "$json" >/dev/null
}

assert_no_package() {
    local json="$1" package="$2"
    jq -e --arg package "$package" '.packages | index($package) == null' "$json" >/dev/null
}

assert_service() {
    local json="$1" service="$2"
    jq -e --arg service "$service" '.services | index($service) != null' "$json" >/dev/null
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for desktop in gnome hyprland kde xfce none; do
    bash "$ROOT/tools/legit-install" --desktop "$desktop" --print-config > "$tmp_dir/$desktop.json"
    jq -e . "$tmp_dir/$desktop.json" >/dev/null
    assert_package "$tmp_dir/$desktop.json" openvpn
    assert_package "$tmp_dir/$desktop.json" networkmanager-openvpn
    assert_package "$tmp_dir/$desktop.json" netexec
    assert_package "$tmp_dir/$desktop.json" nuclei-bin
    assert_package "$tmp_dir/$desktop.json" ttf-jetbrains-mono-nerd
    assert_service "$tmp_dir/$desktop.json" NetworkManager
    assert_service "$tmp_dir/$desktop.json" sshd
done

jq -e '.custom_commands | any(contains("LEGIT-AUR-BEGIN"))' "$tmp_dir/gnome.json" >/dev/null

assert_package "$tmp_dir/gnome.json" gnome
assert_package "$tmp_dir/gnome.json" gnome-terminal
assert_package "$tmp_dir/gnome.json" gnome-console
assert_package "$tmp_dir/gnome.json" ptyxis
assert_service "$tmp_dir/gnome.json" gdm
assert_no_package "$tmp_dir/gnome.json" hyprland
assert_no_package "$tmp_dir/gnome.json" sddm

assert_package "$tmp_dir/hyprland.json" hyprland
assert_service "$tmp_dir/hyprland.json" sddm
assert_no_package "$tmp_dir/hyprland.json" gnome
assert_no_package "$tmp_dir/hyprland.json" gdm

assert_package "$tmp_dir/kde.json" plasma-meta
assert_service "$tmp_dir/kde.json" sddm
assert_package "$tmp_dir/xfce.json" xfce4
assert_service "$tmp_dir/xfce.json" lightdm

for desktop in gnome hyprland kde xfce; do
    assert_no_package "$tmp_dir/none.json" "$desktop"
done
assert_no_package "$tmp_dir/none.json" gdm
assert_no_package "$tmp_dir/none.json" sddm
assert_no_package "$tmp_dir/none.json" lightdm

# Exercise the non-print path: the local repository must be visible while
# Archinstall runs, then the live Pacman configuration must be restored.
mkdir -p "$tmp_dir/share/aur-repo"
cp "$ROOT/packages/"*.list "$tmp_dir/share/"
touch "$tmp_dir/share/aur-repo/legit-aur.db.tar.gz"
touch "$tmp_dir/share/aur-repo/netexec-1-1-x86_64.pkg.tar.zst"
printf '[options]\nArchitecture = auto\n' > "$tmp_dir/pacman.conf"
export LEGIT_SHARE_DIR="$tmp_dir/share"
export LEGIT_PACMAN_CONF="$tmp_dir/pacman.conf"
bash "$ROOT/tools/legit-install" --desktop none > "$tmp_dir/install.log"
grep -q 'Mock Archinstall received the complete toolkit' "$tmp_dir/install.log"
if grep -q 'LEGIT-AUR' "$tmp_dir/pacman.conf"; then
    echo "Temporary LEGIT AUR repository was not restored" >&2
    exit 1
fi

echo "Installer profiles validated: gnome hyprland kde xfce none"
