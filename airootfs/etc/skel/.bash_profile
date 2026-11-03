# LEGIT OS - default user profile (skeleton)
# Sources ~/.bashrc then starts the Hyprland graphical session on tty1.

[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ $(tty) = /dev/tty1 ]]; then
    exec Hyprland
fi
