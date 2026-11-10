#!/usr/bin/env bash
# Mock-only Linux Makefile smoke test. No privileged operations or ISO downloads.
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/mockbin"
cat >"$root/mockbin/podman" <<'MOCK'
#!/bin/sh
printf 'podman %s\n' "$*" >>"$MOCK_LOG"
MOCK
cat >"$root/mockbin/qemu-img" <<'MOCK'
#!/bin/sh
printf 'qemu-img %s\n' "$*" >>"$MOCK_LOG"
[ "$1" = create ] && touch "$4"
MOCK
cat >"$root/mockbin/qemu-system-x86_64" <<'MOCK'
#!/bin/sh
printf 'qemu %s\n' "$*" >>"$MOCK_LOG"
MOCK
chmod +x "$root/mockbin/"*
export PATH="$root/mockbin:$PATH" MOCK_LOG="$root/calls.log"
make LEGIT_DATA_DIR="$root/data" CONTAINER_ENGINE=podman check
make LEGIT_DATA_DIR="$root/data" CONTAINER_ENGINE=podman image
make LEGIT_DATA_DIR="$root/data" CONTAINER_ENGINE=podman all
mkdir -p "$root/data/out" "$root/data/.cache/legit-aur"
touch "$root/data/out/LEGIT_OS-test-x86_64.iso"
touch "$root/data/.cache/legit-aur/test.pkg.tar.zst"
make LEGIT_DATA_DIR="$root/data" CONTAINER_ENGINE=podman vm
make LEGIT_DATA_DIR="$root/data" CONTAINER_ENGINE=podman aur-clean
test ! -e "$root/data/.cache/legit-aur/test.pkg.tar.zst"
make LEGIT_DATA_DIR="$root/data" CONTAINER_ENGINE=podman re
test ! -e "$root/data/out/LEGIT_OS-test-x86_64.iso"
grep -q 'podman run --rm --privileged' "$MOCK_LOG"
grep -q 'legit-os-pacman-cache:/var/cache/pacman/pkg' "$MOCK_LOG"
grep -q 'legit-os-work:/work' "$MOCK_LOG"
if grep -q '/archiso/pacman:/var/cache/pacman/pkg' "$MOCK_LOG"; then
  echo 'ERROR: unsafe host bind cache detected' >&2
  exit 1
fi
grep -q 'qemu -machine' "$MOCK_LOG"
echo 'PASS: Linux Make targets (mock engine + QEMU)'
