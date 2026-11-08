# airootfs - LEGIT OS additions

Files in this directory are layered over Archiso's official `releng` root.
The overlay is intentionally small:

- `usr/share/backgrounds/legit/` contains the LEGIT wallpaper.
- system helpers are copied from `tools/` into `/usr/local/bin` by the build.
- no Hyprland, Quickshell, terminal, Vim or Zsh dotfile is installed here.

Desktop environments and user configuration remain owned by the user.
