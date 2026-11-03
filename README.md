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
├── hyprland/           Hyprland + Waybar configuration (floating-first)
├── branding/           LEGIT OS identity files (same as `motd`...)
├── archinstall/        Archinstall preset (config for installed systems)
├── tools/              helper scripts shipped in the ISO (legit-info, legit-install)
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
```

## Installation on a real machine

From the live ISO, run `legit-install`: it launches the **official
Archinstall** installer with the LEGIT OS preset (`archinstall/user-configuration.json`).
Note: Archinstall does **not** mirror the live environment; the preset lists
the packages applied to the installed system. Disk layout (partitioning /
encryption) stays interactive.

