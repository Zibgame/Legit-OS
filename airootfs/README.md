# airootfs - LEGIT OS additions to the live root filesystem

Files here are layered (via `build/build.sh`) on top of the `releng` airootfs
shipped by the archiso package. Add custom files here exactly where you want
them inside the live system, e.g.:

- `etc/skel/...` for dotfiles applied to every user created in the live env
  (`.zprofile`/`.bash_profile` start the Hyprland session on tty1)
- `usr/local/bin/` for extra helper scripts (legit-shell-start, legit-shell-ctl,
  legit-desktop-init, legit-liveuser-init)
- `usr/share/backgrounds/legit/` for the session wallpaper
- `etc/xdg/mimeapps.list` for the system-wide default applications (Nautilus)
- `etc/sudoers.d/10-legit` so the live desktop user can install packages
- `etc/skel/.config/gtk-3.0|gtk-4.0/settings.ini` (+ the same under `root/`)
  for the Adwaita dark theme, so GTK apps stay dark even without dconf
- `etc/issue`, `etc/profile.d/...` for system tweaks

Build.sh then also layers: `hyprland/` → `etc/skel/.config` and
`/root/.config` (`etc/skel` is what the live desktop user gets),
`legit-shell/` → `.config/quickshell/legit-shell` (both),
`branding/` → `etc/`, `archinstall/` → `etc/`, `tools/` → `usr/local/bin/`.

The tty1 autologin is the normal user `legit`, provisioned at boot by
`legit-liveuser-init` (`profile/airootfs/.../getty@tty1.service.d/autologin.conf`).
GNOME apps (Nautilus) refuse to run as root, so the session must not be root.
