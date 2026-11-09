# LEGIT OS - demarrage de la session graphique sur tty1.
# Pas de display manager : l'utilisateur se connecte en console, Hyprland
# demarre immediatement sur tty1. Le lock screen reste son affaire.
[[ -f ~/.bashrc ]] && . ~/.bashrc

# VirtualBox's virtual GPU hands out invalid EGL buffers, which makes GTK4 /
# libadwaita apps abort. Fall back to the CPU renderer there; real hardware
# keeps GPU acceleration.
if command -v systemd-detect-virt >/dev/null 2>&1 \
   && [ "$(systemd-detect-virt)" = "oracle" ]; then
    export GSK_RENDERER=cairo
fi

if [[ $(tty) = /dev/tty1 && -z $WAYLAND_DISPLAY ]]; then
    exec start-hyprland > /var/log/legit-hyprland.log 2>&1
fi
