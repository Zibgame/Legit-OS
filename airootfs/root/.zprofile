# LEGIT OS - root profile
# Starts the Hyprland graphical session on tty1 (live environment autologin).

if [[ $(tty) = /dev/tty1 && -z $WAYLAND_DISPLAY ]]; then
    exec Hyprland
fi
