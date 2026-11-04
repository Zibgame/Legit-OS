# LEGIT OS

**Offensive Security Linux Distribution**

*Trust me, it's legit.*

LEGIT OS is an Arch Linux-based distribution designed specifically for offensive cybersecurity operations.

Built for penetration testers, red team operators, security researchers, exploit developers, and advanced hackers, LEGIT OS provides a dedicated environment for discovering, exploiting, and analyzing security vulnerabilities.

**Core Focus**
- Offensive Security & Penetration Testing
- Exploit Development & Vulnerability Research
- Red Team Operations & Adversary Simulation
- Reverse Engineering & Binary Exploitation
- Network Exploitation & Security Assessment
- Post-Exploitation Research
- Capture The Flag (CTF)

**System**
- Base: Arch Linux
- Desktop: Hyprland (floating-first configuration)
- Package Manager: Pacman
- Installer: Archinstall
- Philosophy: Offensive by design.

LEGIT OS is built for authorized security research, professional penetration testing, and controlled laboratory environments.

**No disguise. No ambiguity. Offensive Security.**

## Repository layout

```
Legit-OS/
├── Makefile            local ISO build (Docker + archiso, no CI/CD)
├── build/              container recipe + main build script
│   ├── Containerfile
│   └── build.sh
├── profile/            LEGIT OS archiso profile (based on official `releng`)
│   ├── profiledef.sh   image metadata & build modes (LEGIT branding)
│   ├── pacman.conf
│   ├── airootfs/       releng system files + hostname
│   ├── efiboot/ , grub/ , syslinux/
├── packages/
│   ├── system.list         Arch base + Hyprland desktop stack
│   └── offensive-tools.list Offensive tools (official repos only)
├── airootfs/           custom files layered over the releng airootfs
│   ├── usr/local/bin/  legit-shell-start/ctl, legit-desktop-init,
│   │                   legit-liveuser-init (live desktop account)
│   ├── usr/share/backgrounds/legit/  LEGIT OS wallpaper
│   └── etc/            skel GTK/Adwaita dark config, xdg mimeapps defaults
├── legit-shell/        LEGIT Shell: Quickshell taskbar + start menu (QML)
├── hyprland/           Hyprland (lua) + Waybar configuration (floating-first)
├── branding/           LEGIT OS identity files (same as `motd`...)
├── archinstall/        Archinstall preset (config for installed systems)
├── tools/              helper scripts shipped in the ISO (legit-info, legit-install,
│                       legit-ai-install: Codex/Crush/OpenCode installers,
│                       legit-desktop-check: GNOME integration self-test)
├── deploy-vm.sh        push this config into the running VM (no ISO rebuild)
└── out/                generated ISO output (created by `make`)
```

## How the build works

1. `make` builds a small Arch Linux container image (`build/Containerfile`)
   and runs `build/build.sh` inside it.
2. `build.sh` starts from the official archiso `releng` profile shipped by the
   `archiso` package (so the base always matches the toolkit version), layers
   the LEGIT OS customizations on top, generates `packages.x86_64` from the
   two package lists, then runs `mkarchiso`.
3. The final ISO lands in `out/`.

## Usage (Windows / MINGW64 + Docker Desktop)

```bash
make       # build out/LEGIT_OS-<version>-x86_64.iso
make re    # rebuild from scratch (fresh image, output cleared)
make vm    # create/refresh + boot the VirtualBox LEGIT-OS VM (latest ISO)
```

## Desktop (LEGIT Shell + Hyprland)

The live session auto-logs in as the normal user **`legit`** (password `legit`)
on tty1 and starts Hyprland (`hyprland.lua`, floating-first) with **LEGIT
Shell** (Quickshell): a Windows-like taskbar, Start menu and quick-settings
panel. `root` (password `legit`) stays available on the other TTYs
(`Ctrl+Alt+F2`) for rescue.

The session runs as a regular user on purpose: GNOME applications refuse the
root account (`nautilus` exits with code 95), so Nautilus / GNOME Files can
only work this way. `legit-liveuser-init` provisions that account on boot and
is called as `ExecStartPre` of `getty@tty1`.

Under VirtualBox the virtual GPU produces invalid EGL buffers, so the session
profile falls back to the CPU renderer (`GSK_RENDERER=cairo`) when
`systemd-detect-virt` reports `oracle`; real hardware keeps GPU acceleration.

Windows are styled like GNOME: rounded corners, soft shadows, discreet
animations and the native Adwaita (dark) client-side titlebars with
close / minimize / maximize at the top right. GNOME apps keep their own
decorations (`GTK_THEME=Adwaita:dark` + `color-scheme=prefer-dark`), and Qt
apps get Adwaita-like titlebars through `QT_WAYLAND_DECORATION=adwaita`.
The dark look and the default apps are applied at login by
`legit-desktop-init` (`/usr/local/bin`). Plain XWayland apps without native
decorations stay borderless, as on a bare Wayland compositor.

**Icons**: the **Win11** icon theme (faithful Windows 11 icons,
`yeyushengfan258/Win11-icon-theme`) is used everywhere (Nautilus, LEGIT Shell,
taskbar, Start menu). It is not packaged in the Arch repositories, so
`build/build.sh` fetches a pinned upstream commit and installs it into the
image (never fatal: without it the icons fall back to Adwaita).
`legit-desktop-init` sets `icon-theme = Win11-dark`, and
`QT_QPA_PLATFORMTHEME=gtk3` (in `hyprland.lua`) is what makes Qt — and
therefore Quickshell — follow that setting instead of looking only in
`hicolor`. Note: the theme ships no Chromium / VS Code icon, so those two
pins fall back to the icons installed by their own packages.

Essential shortcuts:

| Shortcut | Action |
| --- | --- |
| `Super` | Start menu |
| `Ctrl+Alt+T` | GNOME Terminal |
| `Super+E` | Nautilus (GNOME Files) |
| `Super+Space` | App launcher (wofi) |
| `Super+R` | Run dialog |
| `Alt+F4` | Close window |
| `Alt+Tab` | Cycle windows |
| `Super+Left` / `Super+Right` | Snap window to half |
| `Super+Up` | Maximize |
| `Super+Down` | Minimize |
| `Super+1..5` | Workspaces |
| `Super+D` | Toggle desktop |
| `Print` / `Super+Shift+S` | Screenshot (full / region) |
| `Super+L` | Lock screen |

`legit-shell-ctl startmenu|qs|snap left|snap right|superdown` drives the shell
from the keyboard; the bar and Start menu dispatch window actions through the
Hyprland Lua dispatchers (`hyprctl dispatch 'hl.dsp...'`).

Menu behaviour (Windows-like): one menu at a time, the same key/button toggles
its menu closed, `Escape` closes it, and clicking on a window closes the open
menu while the click still reaches that window. The panels take the keyboard
`Exclusive` while open (so no key leaks to the app, and `Escape` works) but
**never** intercept mouse clicks: no full-screen click-catcher is used. A click
on the empty desktop is the one case Wayland cannot report without such a
catcher, so it leaves the menu open.

## Testing without rebuilding the ISO

`deploy-vm.sh` copies the desktop config (Hyprland Lua, LEGIT Shell QML, the
helper scripts, the theme files, the wallpaper) into the **running**
VirtualBox VM over the Guest Additions control channel, reloads Hyprland and
starts the shell:

```bash
sh deploy-vm.sh        # copy + hyprctl reload + start LEGIT Shell
sh deploy-vm.sh copy   # copy the files only
```

Override the defaults with `VB=... VM=... U=... P=... SRC=...`. Inside the
session, `legit-desktop-check` verifies the GNOME integration (dark
color-scheme, button layout, Nautilus as default file manager, ...).

The script does not install the icon theme (the build does). To test it in a
running VM:

```sh
curl -sL https://github.com/yeyushengfan258/Win11-icon-theme/archive/a5b460a407da143b32f19a503d7fcebb3edf2371.tar.gz \
  | tar xz -C /tmp && /tmp/Win11-icon-theme-a5b460a407da143b32f19a503d7fcebb3edf2371/install.sh \
      -d /usr/share/icons -n Win11
```

Note: Hyprland >= 0.57 reads `hyprland.lua` only, the old `hyprland.conf` is
ignored (hyprlang was dropped), and `hl.env()`/window rules apply to
processes started after the reload.

## Installation on a real machine

From the live ISO, run `legit-install`: it launches the **official
Archinstall** installer with the LEGIT OS preset (`archinstall/user-configuration.json`).
Note: Archinstall does **not** mirror the live environment; the preset lists
the packages applied to the installed system. Disk layout (partitioning /
encryption) stays interactive.

