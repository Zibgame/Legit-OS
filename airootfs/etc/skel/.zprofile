# LEGIT OS - live desktop user profile
#
# The graphical session runs as this normal user, not as root: GNOME
# applications (Nautilus / GNOME Files) refuse to run under the root account
# and exit immediately. root stays available for rescue on the other TTYs.

# VirtualBox's virtual GPU hands out invalid EGL buffers, which makes GTK4 /
# libadwaita apps abort with "Error dispatching to Wayland display". Fall back
# to the CPU renderer there; real hardware keeps GPU acceleration.
if command -v systemd-detect-virt >/dev/null 2>&1 && [ "$(systemd-detect-virt)" = "oracle" ]; then
    export GSK_RENDERER=cairo
fi

# Start the Hyprland session on tty1 (live environment autologin).
if [[ $(tty) = /dev/tty1 && -z $WAYLAND_DISPLAY && $(</sys/class/tty/tty0/active) = tty1 ]]; then
    exec Hyprland --i-am-really-stupid > /var/log/legit-hyprland.log 2>&1
fi
