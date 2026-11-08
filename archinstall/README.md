# Archinstall preset

The preset installs the official-repository LEGIT pentest baseline on a new
Arch system while leaving disk layout, bootloader, encryption and user
creation interactive.

`legit-install` first offers GNOME, Hyprland, KDE Plasma, XFCE or no desktop.
The package and service lists in `desktops/` are independent, so one selection
cannot leak another desktop's packages or files. The Hyprland choice stays
minimal by design: compositor, terminal and desktop plumbing, plus the
`legit-hyprland-config` package (wallpaper + a no-banner configuration) and
`legit-vim-config`. No bar, launcher or dotfile collection is imposed - users
bring their own. All Nerd Fonts, the Vim package set (NERDTree, vim-devicons,
vim-plug) and deezer-tui are included.

OpenVPN, `networkmanager-openvpn`, OpenConnect and WireGuard are installed on
every target. The generated configuration can be inspected safely with
`legit-install --desktop gnome --print-config`.

The live ISO additionally contains maintained AUR tools built by
`build/build.sh`. Their package archives and repository database are embedded
under `/usr/share/legit/aur-repo`. `legit-install` temporarily exposes that
repository to Pacstrap and includes every entry from `aur-tools.list`, then
removes the temporary repository entry from the installed Pacman config. No
AUR compilation or manual post-install command is required.
