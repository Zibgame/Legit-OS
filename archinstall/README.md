# archinstall - LEGIT OS preset

This folder holds the LEGIT OS preset for the official Archinstall installer.
It is shipped inside the live ISO in `/etc/archinstall/`.

## What it does

- `user-configuration.json` : textual (unattended) configuration — locale,
  bootloader, desktop stack (Hyprland) and the offensive-security packages.
  `legit-install` (in the ISO) runs:

      archinstall --config /etc/archinstall/user-configuration.json

## What it does NOT do

- Archinstall does **not** copy the live environment onto the hard drive.
  It performs a fresh installation with the packages listed in
  `user-configuration.json`. The `packages` key must therefore stay in sync
  with `packages/system.list` + `packages/offensive-tools.list`.
- Disk layout stays interactive (user chooses the target disk / encryption in
  Archinstall's UI). Add a `user-disk-layout.json` here and pass
  `--disk-layout` in `tools/legit-install` if you want it unattended too.

## Keeping things in sync

When you add a tool to `packages/offensive-tools.list`, also add (or comment)
it in `user-configuration.json` so it ends up on installed systems.

The JSON schema evolves with Archinstall releases; verify the fields against
the version shipped on the ISO (see `archinstall --help`).
