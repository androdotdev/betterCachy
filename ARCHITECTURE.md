# Architecture

How the pieces fit together, what is tracked, and what is generated at runtime.

## Big picture

```text
                    ┌──────────────────────────────┐
                    │            SDDM              │
                    │  theme: matugen (Qt/QML)     │
                    │  palette: Colors.qml         │
                    │  wallpaper: background file  │
                    └──────────────┬───────────────┘
                                   │ login
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│ Hyprland (Wayland compositor)                                    │
│  ~/.config/hypr/hyprland.lua ──require──▶ hyprland-settings.lua │
│  autostart: hyprpaper, kando, kdeconnectd                        │
│                                                                  │
│  hyprpaper ──▶ desktop wallpaper                                 │
│  hyprlock  ◀── colors.conf + lock-wall.conf                      │
│  hypridle  ──▶ lock on idle / sleep                              │
│                                                                  │
│  systemd --user: quickshell.service, vicinae.service,            │
│                  swayosd.service                                 │
│                                                                  │
│  quickshell ──▶ bar + OSD (reads colors.json)                    │
└──────────────────────────────────────────────────────────────────┘
                                   ▲
                                   │ theme-apply <wallpaper>
                    ┌──────────────┴───────────────┐
                    │           Matugen            │
                    │  config.toml + templates/*   │
                    │  → GTK, Qt, Hypr, Quickshell,│
                    │    SDDM palettes             │
                    └──────────────────────────────┘
```

## Repository layout

```text
betterCachy/
├── README.md                          setup / restore instructions
├── ARCHITECTURE.md                    this file
├── install.sh                         restores home/ into $HOME (with backup)
├── .gitignore                         runtime + generated state exclusions
├── home/                              mirrors $HOME (dotfiles + key configs)
│   ├── .bashrc .bash_profile .bash_logout
│   ├── .zshrc .p10k.zsh          zsh + powerlevel10k
│   ├── .gitconfig .gtkrc-2.0
│   ├── .local/bin/
│   │   ├── theme-apply        main theming entry point (fish)
│   │   └── kvantum-apply      rebuilds the Kvantum theme (fish)
│   ├── .config/
│   │   ├── hypr/              Hyprland, hyprpaper, hyprlock, hypridle
│   │   ├── matugen/           Matugen config + templates
│   │   ├── sddm-matugen/      SDDM theme source + install.sh
│   │   ├── quickshell/        Wayland bar + OSD shell
│   │   ├── systemd/user/      user services
│   │   ├── uwsm/env           uwsm session environment
│   │   ├── Kvantum/           Kvantum theme
│   │   ├── gtk-3.0/ gtk-4.0/  GTK themes
│   │   ├── qt5ct/ qt6ct/      Qt colour schemes
│   │   ├── kitty/ kando/ nwg-look/ noctalia/   launchers + terminal
│   │   └── (no orbitals, no X11 legacy)         cleaned out
│   ├── (no editors, no terminals, no btop/cava, no opencode/mise)
│   └── (no KDE, no i3/polybar/picom/swash)
├── system/                            reference snapshot of root-owned files
│   └── etc/sddm.conf.d/zz-matugen-theme.conf
│       + usr/share/sddm/themes/matugen/   (Main.qml, widgets, theme.conf, Colors.qml)
├── packages/
│   ├── pacman-explicit.txt    official repo packages (pacman -Qqe)
│   ├── pacman-foreign.txt     AUR/foreign packages (pacman -Qqm)
│   └── flatpak.txt            Flatpak app IDs
└── demo.png                           screenshot of the desktop
```

## Flow

1. **`install.sh`** clones/restores `home/` into `$HOME` with backup; `system/` is a
   reference only. `--system` additionally runs the SDDM install script with `sudo`.
2. **`theme-apply <wallpaper>`** (fish, in `home/.local/bin/`) calls Matugen via the
   templates, then:
   - copies the wallpaper to `~/.config/sddm-matugen/background` (the fixed path the
     SDDM greeter reads),
   - rewrites `~/.config/hypr/hyprpaper.conf` + restarts `hyprpaper`,
   - with `-l`, rewrites `lock-wall.conf` for hyprlock,
   - sets `adw-gtk3-dark` + dark colour-scheme via `gsettings`.
3. **`kvantum-apply`** (fish) rebuilds the Kvantum theme from the Matugen palette.
4. **SDDM** (`sudo ~/.config/sddm-matugen/install.sh`) installs to `/usr/share/sddm/themes/`
   and grants the `sddm` greeter ACL read access.

Because everything colour-related is generated from Matugen + a single wallpaper, changing
the palette later is a single command — no manual edits to GTK, Qt, Hypr, Quickshell or SDDM
configs.

## Generated vs. tracked files

Generated at theme time (safe to delete; run `theme-apply` to recreate):

- `~/.config/quickshell/colors.json`
- `~/.config/hypr/colors.conf`
- `~/.config/gtk-{3,4}.0/gtk.css`
- `~/.config/qt{5,6}ct/colors/matugen.conf`
- `~/.config/Kvantum/Matugen/*`
- `~/.config/sddm-matugen/Colors.qml`
- `~/.config/sddm-matugen/background`
- `~/.config/hypr/hyprpaper.conf`, `lock-wall.conf`

Tracked here as snapshots of the current machine; treat them as outputs, not sources. The
sources are the templates in `~/.config/matugen/templates/`, the theme QML in
`~/.config/sddm-matugen/theme/`, and the scripts in `~/.local/bin/`.

## Restore flow

`./install.sh` runs `rsync -a --backup --backup-dir=~/.betterCachy-backup/<ts>` from
`home/` into `$HOME`, so the repo's tree maps 1:1 onto real paths. Nothing outside
`home/` is touched; `system/` is only a reference. `--system` additionally runs the SDDM
`install.sh` with `sudo`. After restoring, run `theme-apply` to regenerate every palette
and then enable the user services (see README).
