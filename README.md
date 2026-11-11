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
| `.config/mimeapps.list` | Zen Browser as the default for web links and HTML |
| `.gitconfig` | Git identity, GitHub auth through `gh` |
| `packages.txt` | apt packages the configs depend on |
| `.claude/` | Claude Code: global `CLAUDE.md`, status line, plugins and the `git-workflow` skill |

## Install

Files are symlinked into `$HOME` with [GNU Stow](https://www.gnu.org/software/stow/),
so editing a config in place edits the repo:

```sh
git clone https://github.com/bentors/dotfiles ~/dotfiles
cd ~/dotfiles
grep -vE '^\s*(#|$)' packages.txt | xargs sudo apt install -y
stow .
# runtime-rewritten files are copied, not linked
cp .config/waybar/art.css ~/.config/waybar/
cp .config/mimeapps.list ~/.config/
# purple accent for GTK/libadwaita apps (dconf, not a file)
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-purple-dark'
gsettings set org.gnome.desktop.interface accent-color 'purple'
```

`.stowrc` links files one by one (`--no-folding`), so app state written next to
them stays out of the repo. `.stow-local-ignore` skips `.claude/settings.json`,
`waybar/art.css` and `mimeapps.list`, which tools rewrite at runtime. If a file already exists,
`stow` refuses to replace it; move it away (or use `stow --adopt .` and review
`git diff`). `stow -D .` removes the links.

Wallpapers are not included; `scripts/wallpaper /path/to/image.png` sets one.

Dependencies available in apt are listed in `packages.txt` (ImageMagick must
be 7, for `magick`). Two come from elsewhere: the `vicinae` launcher and Zen
Browser.

The bar and `Super+B` expect Zen Browser at `~/.local/opt/zen/zen`; the island
follows Spotify. Monitor layout and the `intel_backlight` device are specific to
this machine; adjust them in `hyprland.conf`, `scripts/backlight` and
`swaync/config.json`.

## Claude Code

`stow .` links everything in `.claude/` except `settings.json`, which holds only portable keys
(theme, status line, attribution off, plugins and marketplaces); merge it into
an existing file instead of overwriting it. The status line needs `jq`.
Credentials, history, memory and machine-specific hooks are never committed.

Not versioned, reinstalled by their own tools:

- Caveman skills (`caveman`, `ultracave`, `megacave`), hooks and MCP:
  `npm i -g @caveman-ai/cli && caveman setup --agent-native claude`
- claude.ai connectors (Gmail, Slack, Notion...) come back with the login;
  the GitHub MCP comes with the `github` plugin.
