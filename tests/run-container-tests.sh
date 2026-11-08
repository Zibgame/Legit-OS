#!/usr/bin/env bash
set -euo pipefail

# The host proxy cannot validate Arch's HTTPS certificate in a fresh image.
# Pacman still verifies package signatures while this bootstraps the CA bundle.
printf 'Server = http://geo.mirror.pkgbuild.com/$repo/os/$arch\n' \
    > /etc/pacman.d/mirrorlist
pacman -Sy --noconfirm archlinux-keyring ca-certificates ca-certificates-mozilla
update-ca-trust
pacman -Syu --noconfirm --needed base-devel jq arch-install-scripts

cp -a /src /work
chmod +x /work/tools/legit-install /work/tests/mock-bin/* \
    /work/tests/test-installer.sh /work/tests/test-offline-repo.sh
cd /work
tests/test-installer.sh
tests/test-offline-repo.sh
