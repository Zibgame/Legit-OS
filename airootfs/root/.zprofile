# LEGIT OS - root profile
# Starts the Hyprland graphical session on tty1 (live environment autologin).

if [[ $(tty) = /dev/tty1 && -z $WAYLAND_DISPLAY && $(</sys/class/tty/tty0/active) = tty1 ]]; then
    exec Hyprland --i-am-really-stupid > /var/log/legit-hyprland.log 2>&1
fi