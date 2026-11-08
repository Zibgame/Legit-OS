# LEGIT OS - default user profile (skeleton)
# Sources ~/.bashrc then starts the Hyprland graphical session on tty1.

[[ -f ~/.bashrc ]] && . ~/.bashrc

# VirtualBox's virtual GPU hands out invalid EGL buffers, which makes GTK4 /
# libadwaita apps abort with "Error dispatching to Wayland display". Fall back
# to the CPU renderer there; real hardware keeps GPU acceleration.
if command -v systemd-detect-virt >/dev/null 2>&1 && [ "$(systemd-detect-virt)" = "oracle" ]; then
    export GSK_RENDERER=cairo
fi

if [[ $(tty) = /dev/tty1 && -z $WAYLAND_DISPLAY && $(</sys/class/tty/tty0/active) = tty1 ]]; then
    exec start-hyprland > /var/log/legit-hyprland.log 2>&1
fi
