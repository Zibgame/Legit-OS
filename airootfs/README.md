# airootfs - LEGIT OS additions to the live root filesystem

Files here are layered (via `build/build.sh`) on top of the `releng` airootfs
shipped by the archiso package. Add custom files here exactly where you want
them inside the live system, e.g.:

- `etc/skel/...` for dotfiles applied to every user created in the live env
- `usr/local/bin/` for extra helper scripts
- `etc/issue`, `etc/profile.d/...` for system tweaks

Build.sh then also layers: `hyprland/` → `etc/skel/.config`,
`branding/` → `etc/`, `archinstall/` → `etc/`, `tools/` → `usr/local/bin/`.
