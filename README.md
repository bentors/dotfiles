# dotfiles

Hyprland desktop on Ubuntu with a purple Waybar and a media "dynamic island".

![](https://img.shields.io/badge/WM-Hyprland-8b5cf6) ![](https://img.shields.io/badge/bar-Waybar-8b5cf6)

## What's inside

| Path | What it is |
|---|---|
| `.config/hypr/` | Hyprland, hyprlock and hypridle configs, plus volume/backlight/wallpaper scripts |
| `.config/waybar/` | Bar config and style, and the dynamic island: clock, equalizer, album art ring |
| `.config/waybar/scripts/player-panel.py` | GTK4 Spotify panel that opens on hover over the island |
| `.config/kitty/` | Translucent black terminal |
| `.config/fastfetch/` | Purple fetch on terminal start |
| `.config/vicinae/` | Launcher settings (`Super+Space`) |

## Install

Copy the folders into `~/.config/` (or symlink them). Wallpapers are not
included; `scripts/wallpaper /path/to/image.png` sets one.

Main dependencies: `hyprland`, `waybar`, `swaybg`, `hyprlock`, `hypridle`,
`kitty`, `fastfetch`, `vicinae`, `playerctl`, `wireplumber` (`wpctl`),
`imagemagick`, `cava`, `wl-clipboard`, `python3-gi` with GTK 4 and libadwaita,
and FontAwesome 4.
