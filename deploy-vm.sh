#!/bin/sh
# LEGIT OS - deploy the repo's desktop config into the running VirtualBox VM.
#
# This is the fast path to test changes without rebuilding the ISO: it only
# copies files over the Guest Additions control channel and reloads Hyprland.
# It never touches the ISO, Docker, or the VM's disk.
#
#   sh deploy-vm.sh          # copy the config, reload Hyprland, start the shell
#   sh deploy-vm.sh copy     # only copy the files (no reload / no shell start)
#   sh deploy-vm.sh user     # also provision the non-root live user and switch
#                            # the tty1 autologin to it (reboot-free session swap)
#
# Requirements: the LEGIT-OS VM running with Guest Additions, reachable with
# the live credentials (root / legit). Override with:
#   VB=/path/to/VBoxManage VM=LEGIT-OS U=root P=legit SRC=/repo sh deploy-vm.sh
set -e

# MSYS2/Git Bash rewrites Unix-looking arguments passed to native Windows
# programs.  That turns the guest executable `/bin/sh` into a host path such
# as `C:/Program Files/Git/usr/bin/sh`, which VBoxManage then (correctly)
# cannot find inside the VM.  All host paths used below are already converted
# explicitly through cygpath, so disable this implicit conversion globally.
case "${MSYSTEM:-}" in
    MINGW*|MSYS*) MSYS2_ARG_CONV_EXCL='*'; export MSYS2_ARG_CONV_EXCL ;;
esac

VB="${VB:-D:/Other/App/VirtualBox/VBoxManage.exe}"
VM="${VM:-LEGIT-OS}"
U="${U:-root}"
P="${P:-legit}"

if [ -z "${SRC:-}" ]; then
    if command -v cygpath >/dev/null 2>&1; then
        SRC="$(cygpath -m "$(pwd)")"
    else
        SRC="$(pwd)"
    fi
fi

gc()  { "$VB" guestcontrol "$VM" "$@"; }
gsh() { gc run --exe /bin/sh --username "$U" --password "$P" -- -c "$1"; }
cpy() { gc copyto --username "$U" --password "$P" "$1" "$2"; }

# hyprctl / session helpers live in the guest: the session user is detected
# from the running compositor, so this works whether the desktop runs as root
# or as the live user "legit".

echo ">>> deploy  VM=$VM  user=$U  src=$SRC"

# 1. Target directories.
gsh "mkdir -p /root/.config/hypr /root/.config/quickshell/legit-shell/orpen \
     /root/.config/gtk-3.0 /root/.config/gtk-4.0 /root/.config/serpantinum \
     /usr/local/bin \
     /usr/share/backgrounds/legit /etc/xdg /etc/sudoers.d"

# 2. Files. Hyprland >= 0.57 only reads hyprland.lua (hyprlang was dropped),
#    so this is what makes the desktop config load at all.
cpy "$SRC/hyprland/hypr/hyprland.lua"               "/root/.config/hypr/hyprland.lua"
cpy "$SRC/legit-shell/shell.qml"                     "/root/.config/quickshell/legit-shell/shell.qml"
cpy "$SRC/legit-shell/Taskbar.qml"                   "/root/.config/quickshell/legit-shell/Taskbar.qml"
cpy "$SRC/legit-shell/StartMenu.qml"                 "/root/.config/quickshell/legit-shell/StartMenu.qml"
cpy "$SRC/legit-shell/QuickSettings.qml"             "/root/.config/quickshell/legit-shell/QuickSettings.qml"
cpy "$SRC/legit-shell/SystemGlyph.qml"               "/root/.config/quickshell/legit-shell/SystemGlyph.qml"
cpy "$SRC/legit-shell/ControlSlider.qml"              "/root/.config/quickshell/legit-shell/ControlSlider.qml"
cpy "$SRC/legit-shell/ControlTile.qml"                "/root/.config/quickshell/legit-shell/ControlTile.qml"
cpy "$SRC/legit-shell/DankAudioService.qml"           "/root/.config/quickshell/legit-shell/DankAudioService.qml"
cpy "$SRC/legit-shell/DankBluetoothService.qml"       "/root/.config/quickshell/legit-shell/DankBluetoothService.qml"
cpy "$SRC/legit-shell/DankNetworkService.qml"         "/root/.config/quickshell/legit-shell/DankNetworkService.qml"
cpy "$SRC/legit-shell/DankBrightnessService.qml"      "/root/.config/quickshell/legit-shell/DankBrightnessService.qml"
cpy "$SRC/legit-shell/BtPanel.qml"                    "/root/.config/quickshell/legit-shell/BtPanel.qml"
cpy "$SRC/legit-shell/VolumePanel.qml"                "/root/.config/quickshell/legit-shell/VolumePanel.qml"
cpy "$SRC/legit-shell/CalendarPanel.qml"              "/root/.config/quickshell/legit-shell/CalendarPanel.qml"
cpy "$SRC/legit-shell/orpen/ControlCenter.qml"       "/root/.config/quickshell/legit-shell/orpen/ControlCenter.qml"
cpy "$SRC/legit-shell/orpen/ToggleGrid.qml"          "/root/.config/quickshell/legit-shell/orpen/ToggleGrid.qml"
cpy "$SRC/legit-shell/orpen/SliderRow.qml"           "/root/.config/quickshell/legit-shell/orpen/SliderRow.qml"
cpy "$SRC/legit-shell/orpen/WifiPanel.qml"           "/root/.config/quickshell/legit-shell/orpen/WifiPanel.qml"
cpy "$SRC/legit-shell/orpen/BtPanel.qml"             "/root/.config/quickshell/legit-shell/orpen/BtPanel.qml"
cpy "$SRC/legit-shell/orpen/MediaCard.qml"           "/root/.config/quickshell/legit-shell/orpen/MediaCard.qml"
cpy "$SRC/legit-shell/orpen/Theme.qml"               "/root/.config/quickshell/legit-shell/orpen/Theme.qml"
cpy "$SRC/legit-shell/ORPEN123-NOTICE.md"            "/root/.config/quickshell/legit-shell/ORPEN123-NOTICE.md"
cpy "$SRC/airootfs/usr/local/bin/legit-shell-start"  "/usr/local/bin/legit-shell-start"
cpy "$SRC/airootfs/usr/local/bin/legit-shell-ctl"    "/usr/local/bin/legit-shell-ctl"
cpy "$SRC/airootfs/usr/local/bin/legit-desktop-init" "/usr/local/bin/legit-desktop-init"
cpy "$SRC/airootfs/usr/local/bin/legit-liveuser-init" "/usr/local/bin/legit-liveuser-init"
cpy "$SRC/tools/legit-desktop-check"                 "/usr/local/bin/legit-desktop-check"
cpy "$SRC/tools/legit-terminal"                      "/usr/local/bin/legit-terminal"
cpy "$SRC/airootfs/usr/share/backgrounds/legit/ocean-balcony.jpeg" \
                                                     "/usr/share/backgrounds/legit/ocean-balcony.jpeg"
cpy "$SRC/airootfs/etc/xdg/mimeapps.list"            "/etc/xdg/mimeapps.list"
cpy "$SRC/airootfs/etc/sudoers.d/10-legit"           "/etc/sudoers.d/10-legit"
cpy "$SRC/airootfs/etc/skel/.zprofile"               "/etc/skel/.zprofile"
cpy "$SRC/airootfs/etc/skel/.bash_profile"           "/etc/skel/.bash_profile"
cpy "$SRC/airootfs/etc/skel/.vimrc"                  "/etc/skel/.vimrc"
cpy "$SRC/airootfs/etc/skel/.zshrc"                  "/etc/skel/.zshrc"
cpy "$SRC/airootfs/root/.config/gtk-3.0/settings.ini" "/root/.config/gtk-3.0/settings.ini"
cpy "$SRC/airootfs/root/.config/gtk-4.0/settings.ini" "/root/.config/gtk-4.0/settings.ini"
cpy "$SRC/airootfs/root/.config/xdg-terminals.list"  "/root/.config/xdg-terminals.list"
# Serpantinum shell preferences (dock on the left edge, autohide + size).
mkdir -p "$SRC/airootfs/root/.config/serpantinum" 2>/dev/null || true
cpy "$SRC/airootfs/root/.config/serpantinum/settings.json" \
                                                     "/root/.config/serpantinum/settings.json"
cpy "$SRC/profile/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf" \
                                                     "/tmp/legit-autologin.conf"

# 2b. Serpantinum vendor tree (Settings panel, wallpaper switcher, music+EQ
#     panel — AGPL-3.0, see legit-shell/serpantinum/NOTICE.md). Packed into a
#     single tarball: guestcontrol copies files one by one and the vendored
#     tree has hundreds of them.
# Keep tar on a POSIX path.  On Git Bash, $SRC is intentionally converted to
# C:/... for VBoxManage, but GNU tar parses that drive-letter colon as a
# remote-host separator when it is used as the archive output path.
ARCHIVE=.deploy-serpantinum.tgz
tar -czf "$ARCHIVE" -C legit-shell serpantinum
cpy "$SRC/.deploy-serpantinum.tgz" "/tmp/.deploy-serpantinum.tgz"
gsh "tar -xzf /tmp/.deploy-serpantinum.tgz -C /root/.config/quickshell/legit-shell \
     && rm -f /tmp/.deploy-serpantinum.tgz && ls /root/.config/quickshell/legit-shell/serpantinum >/dev/null && echo VENDOR_OK"
rm -f "$ARCHIVE"

# 3. Permissions, mirror the config into /etc/skel for new users, and retire
#    the legacy hyprlang file (ignored by Hyprland >= 0.57 anyway).
gsh "chmod 755 /usr/local/bin/legit-*; chmod 440 /etc/sudoers.d/10-legit; \
     chmod 644 /usr/share/backgrounds/legit/ocean-balcony.jpeg \
               /etc/xdg/mimeapps.list /etc/skel/.zprofile /etc/skel/.bash_profile \
               /etc/skel/.vimrc /etc/skel/.zshrc; \
     mkdir -p /etc/skel/.config; \
     install -Dm644 /root/.config/hypr/hyprland.lua /etc/skel/.config/hypr/hyprland.lua; \
     cp -a /root/.config/quickshell /etc/skel/.config/; \
     cp -a /root/.config/gtk-3.0 /root/.config/gtk-4.0 /etc/skel/.config/; \
     cp -a /root/.config/xdg-terminals.list /etc/skel/.config/; \
     chmod -R a+rX /etc/skel/.config; \
     for d in /root/.config/hypr /etc/skel/.config/hypr; do \
         if [ -f \$d/hyprland.conf ]; then mv \$d/hyprland.conf \$d/hyprland.conf.legacy; fi; \
     done; \
     echo FILES_OK"

# 3b. Push the config into the home of the user that actually owns the running
#     compositor. Hyprland reads $HOME/.config/hypr/hyprland.lua, and for the
#     live desktop account that is /home/legit, NOT /root. Forgetting this means
#     the session keeps running the previous config after every deploy.
gsh "U=\$(ps -o user= -C Hyprland 2>/dev/null | head -1); \
     if [ -n \"\$U\" ] && [ \"\$U\" != root ]; then \
         H=\$(getent passwd \"\$U\" | cut -d: -f6); \
         install -d -o \"\$U\" -g \"\$U\" \"\$H/.config/hypr\" \"\$H/.config/quickshell\"; \
         install -m 644 /root/.config/hypr/hyprland.lua \"\$H/.config/hypr/hyprland.lua\"; \
         cp -a /root/.config/quickshell/. \"\$H/.config/quickshell/\"; \
         cp -a /root/.config/gtk-3.0 /root/.config/gtk-4.0 /root/.config/xdg-terminals.list \"\$H/.config/\" 2>/dev/null; \
         mkdir -p \"\$H/.config/serpantinum\"; \
         install -m 644 /root/.config/serpantinum/settings.json \"\$H/.config/serpantinum/settings.json\"; \
         install -m 644 /etc/skel/.vimrc \"\$H/.vimrc\"; \
         install -m 644 /etc/skel/.zshrc \"\$H/.zshrc\"; \
         chown \"\$U\":\"\$U\" \"\$H/.vimrc\" \"\$H/.zshrc\"; \
         chown -R \"\$U\":\"\$U\" \"\$H/.config\"; \
         chmod -R u+rwX,go+rX \"\$H/.config/hypr\" \"\$H/.config/quickshell\"; \
         echo \"SYNCED to \$H\"; \
     fi"

if [ "${1:-}" = "copy" ]; then echo '>>> copy only, done.'; exit 0; fi

# Older development ISOs did not yet contain Quickshell. A live ISO loses
# packages installed in its RAM overlay at every shutdown, so make the fast
# deploy path self-healing instead of leaving Hyprland on an empty desktop.
if ! gsh "command -v quickshell >/dev/null 2>&1"; then
    echo '>>> quickshell is missing from this ISO; installing it in the live session...'
    gsh "pacman -Sy --noconfirm quickshell"
fi

# Older ISOs still boot the releng profile's systemd-networkd services.  The
# current shell uses NetworkManager (nmcli and Quickshell.Networking), so make
# the live-deploy environment match the Archiso sources before testing it.
gsh "if command -v nmcli >/dev/null 2>&1 \
        && ! systemctl is-active --quiet NetworkManager; then \
         systemctl stop systemd-networkd.service systemd-networkd.socket 2>/dev/null || true; \
         systemctl start NetworkManager; \
     fi; \
     systemctl start bluetooth.service 2>/dev/null || true"

# 4. Optionally move the live session onto the normal user. GNOME apps
#    (Nautilus) abort as root, so the desktop has to run as a regular account.
if [ "${1:-}" = "user" ]; then
    echo '>>> provisioning the live desktop user...'
    gsh "/usr/local/bin/legit-liveuser-init && echo USER_OK"
    gsh "mkdir -p /home/legit/.config; \
         cp -a /root/.config/hypr /root/.config/quickshell \
               /root/.config/gtk-3.0 /root/.config/gtk-4.0 \
               /root/.config/xdg-terminals.list /home/legit/.config/; \
         cp -a /etc/skel/.zprofile /etc/skel/.bash_profile \
               /etc/skel/.vimrc /etc/skel/.zshrc /home/legit/; \
         chown -R legit:legit /home/legit; \
         install -Dm644 /tmp/legit-autologin.conf \
             /etc/systemd/system/getty@tty1.service.d/autologin.conf; \
         systemctl daemon-reload; \
         echo SWITCHING_SESSION"
    gsh "systemctl restart getty@tty1"
    gsh "sleep 30; echo '--- session ---'; ps -eo user,comm | grep -E 'Hyprland|quickshell' | head -3"
    echo '>>> tty1 now autologins as legit; the session was restarted.'
    echo '    Re-run "sh deploy-vm.sh" after edits: it detects the session user.'
    exit 0
fi

# 5. Reload Hyprland so the Lua config (decorations, binds, rules) applies,
#    then (re)apply the theme and start the shell inside the running session so
#    WAYLAND_DISPLAY and friends are set. The session user is detected from the
#    running compositor (works for root and for the live user "legit").
gsh "U=\$(ps -o user= -C Hyprland 2>/dev/null | head -1); \
     [ -n \"\$U\" ] || { echo 'NO HYPRLAND SESSION'; exit 0; }; \
     R=/run/user/\$(id -u \"\$U\"); H=\$(ls -t \$R/hypr 2>/dev/null | head -1); \
     as() { runuser -u \"\$U\" -- env XDG_RUNTIME_DIR=\$R HYPRLAND_INSTANCE_SIGNATURE=\$H \"\$@\"; }; \
     echo \"session user: \$U (\$R)\"; \
     as hyprctl reload; as hyprctl configerrors; \
     as hyprctl dispatch 'hl.dsp.exec_cmd(\"swaybg -i /usr/share/backgrounds/legit/ocean-balcony.jpeg -m fill\")'; \
     as hyprctl dispatch 'hl.dsp.exec_cmd(\"mako\")'; \
     as hyprctl dispatch 'hl.dsp.exec_cmd(\"legit-desktop-init\")'; \
     as pkill -x quickshell 2>/dev/null || true; sleep 1; \
     as hyprctl dispatch 'hl.dsp.exec_cmd(\"legit-shell-start\")'; \
     echo DISPATCH_OK"

echo ">>> deployed. Verify inside the VM with:  legit-desktop-check"
