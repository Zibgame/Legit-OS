# Archinstall preset

The preset installs the official-repository LEGIT pentest baseline on a new
Arch system while leaving disk layout, bootloader, encryption and user
creation interactive.

`legit-install` first offers GNOME, Hyprland, KDE Plasma, XFCE or no desktop.
The package and service lists in `desktops/` are independent, so one selection
cannot leak another desktop's packages or files. The Hyprland choice is a clean
upstream setup: no LEGIT Hyprland configuration and no Quickshell are copied.
All Nerd Fonts, Vim, NERDTree and vim-devicons are included system-wide.

OpenVPN, `networkmanager-openvpn`, OpenConnect and WireGuard are installed on
every target. The generated configuration can be inspected safely with
`legit-install --desktop gnome --print-config`.

The live ISO additionally contains maintained AUR tools built by
`build/build.sh`. Their package archives and repository database are embedded
under `/usr/share/legit/aur-repo`. `legit-install` temporarily exposes that
repository to Pacstrap and includes every entry from `aur-tools.list`, then
removes the temporary repository entry from the installed Pacman config. No
AUR compilation or manual post-install command is required.
