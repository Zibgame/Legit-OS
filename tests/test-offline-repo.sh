#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
chmod 755 "$work_dir"

cp -a "$ROOT/tests/fixtures/local-package" "$work_dir/package"
mkdir -p "$work_dir/repo" "$work_dir/target"
useradd -M -s /bin/bash legit-test-builder
chown -R legit-test-builder:legit-test-builder "$work_dir/package"
runuser -u legit-test-builder -- bash -c "cd '$work_dir/package' && makepkg --noconfirm"
cp "$work_dir/package/"*.pkg.tar.zst "$work_dir/repo/"
repo-add "$work_dir/repo/legit-aur.db.tar.gz" "$work_dir/repo/"*.pkg.tar.zst

cp /etc/pacman.conf "$work_dir/pacman.conf"
printf '\n[legit-aur]\nSigLevel = Optional TrustAll\nServer = file://%s\n' \
    "$work_dir/repo" >> "$work_dir/pacman.conf"

pacstrap -C "$work_dir/pacman.conf" -K "$work_dir/target" legit-offline-test
test -f "$work_dir/target/usr/share/legit/offline-repo-test"
pacman --root "$work_dir/target" -Q legit-offline-test
echo "Offline Pacman repository validated through pacstrap"
