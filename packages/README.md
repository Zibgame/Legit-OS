# LEGIT OS package lists

`build/build.sh` concatenates both lists (after stripping comments and blank
lines) into `packages.x86_64` inside the archiso profile used at build time.

- `system.list` — Arch base, firmware, boot, networking, Hyprland desktop
  stack, GNOME/libadwaita integration (Nautilus, GNOME Terminal, Adwaita
  dark theme), fonts, utilities.
- `offensive-tools.list` — offensive security tools available in the **official
  Arch repositories only** (no personal Pacman repository, no AUR at build
  time). AUR candidates are listed commented-out at the bottom.
- `dev-tools.list` — toolchain (base-devel, clang, cmake, python, node, rust),
  editors, QEMU and `archiso` so the OS can rebuild its own ISO (self-hosting).

Both files: one package per line, `#` comments allowed, blank lines ignored.
