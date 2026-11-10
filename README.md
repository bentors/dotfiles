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
| `.config/wofi/` | App menu style (`$menu` and the bar's launcher button) |
| `.config/swaync/` | Notification center with Wi-Fi, Bluetooth, volume and media controls |
| `.config/rofi/wallpaper.rasi` | Thumbnail grid used by `scripts/wallpaper` |
| `.config/fish/` | Shell prompt, clock on the right, fastfetch greeting |
| `.gitconfig` | Git identity, GitHub auth through `gh` |
| `.claude/` | Claude Code: global `CLAUDE.md`, status line, plugins and the `git-workflow` skill |

## Install

Copy the folders into `~/.config/` (or symlink them). Wallpapers are not
included; `scripts/wallpaper /path/to/image.png` sets one.

Main dependencies: `hyprland`, `waybar`, `swaybg`, `hyprlock`, `hypridle`,
`hyprpolkitagent`, `kitty`, `fastfetch`, `vicinae`, `wofi`, `swaync`, `rofi`,
`fish`, `playerctl`, `wireplumber` (`wpctl`), `cava`, ImageMagick 7 (`magick`),
`curl`, `wl-clipboard`, `cliphist`, `grim`, `slurp`, `libnotify-bin`,
`brightnessctl`, `blueman`, `network-manager-gnome`, `pavucontrol`, `nwg-bar`,
`nautilus`, `jq`, `python3-gi` with GTK 4 and libadwaita, FontAwesome 4,
Ubuntu Sans and URW Gothic (`fonts-urw-base35`).

The bar and `Super+B` expect Zen Browser at `~/.local/opt/zen/zen`; the island
follows Spotify. Monitor layout and the `intel_backlight` device are specific to
this machine; adjust them in `hyprland.conf`, `scripts/backlight` and
`swaync/config.json`.

## Claude Code

Copy `.claude/*` into `~/.claude/`. `settings.json` holds only portable keys
(theme, status line, attribution off, plugins and marketplaces); merge it into
an existing file instead of overwriting it. The status line needs `jq`.
Credentials, history, memory and machine-specific hooks are never committed.

Not versioned, reinstalled by their own tools:

- Caveman skills (`caveman`, `ultracave`, `megacave`), hooks and MCP:
  `npm i -g @caveman-ai/cli && caveman setup --agent-native claude`
- claude.ai connectors (Gmail, Slack, Notion...) come back with the login;
  the GitHub MCP comes with the `github` plugin.
