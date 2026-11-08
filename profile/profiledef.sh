#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="LEGIT_OS"
iso_label="LEGIT_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="LEGIT OS <https://legit-os.local>"
iso_application="LEGIT OS Live - Offensive Security Distribution"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="legit"
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# zstd uses all available cores and is dramatically faster than xz for local
# development builds. Level 6 keeps a reasonable image size without making
# iteration wait on compression.
# zstd: fast local-build compression (the disk no longer constrains us).
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '6' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
kernel_params_aarch64="clk_ignore_unused pd_ignore_unused arm64.nopauth"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/legit-info"]="0:0:755"
  ["/usr/local/bin/legit-install"]="0:0:755"
  ["/usr/local/bin/legit-ai-install"]="0:0:755"
  ["/usr/local/bin/legit-personalize"]="0:0:755"
  ["/usr/local/bin/legit-tools-install"]="0:0:755"
  ["/usr/local/bin/legit-vpn"]="0:0:755"
)
