# LEGIT OS package lists

`build/build.sh` converts these lists into Archiso's `packages.x86_64`:

- `system.list`: bootable Arch base, networking, browsers and terminal/editor
  compatibility. `@nerd-fonts` expands to every package in Arch's official
  `nerd-fonts` group.
- `offensive-tools.list`: maintained security tools from official Arch repos.
- `aur-tools.list`: important modern HTB tools absent from official repos.
  They are built as an unprivileged user into a temporary local Pacman repo.
- `dev-tools.list`: compilers and utilities useful for exploit development.
- `releng-essentials.list`: packages required by Archiso's live environment.

The lists do not install a desktop environment and do not contain dotfiles.
One package appears per line; comments and blank lines are ignored.
