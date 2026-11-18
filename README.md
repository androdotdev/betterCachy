# betterCachy

A personal Wayland desktop for **CachyOS**, kept as a **configuration backup**. It is
not a distro and not a spin: it is the hand-written dotfiles, the QML shell, the theme
pipeline and the system integration that turn a plain CachyOS install into this
desktop.

There is no companion application. The desktop runs from the configs in this repo;
restore them with `install.sh`, edit them in place, and keep private state off Git.

> Deep-dive documentation: [`ARCHITECTURE.md`](ARCHITECTURE.md)

> Shell tweaking guide: [`home/.config/quickshell/README.md`](home/.config/quickshell/README.md)

---

## What it comes with

A one-glance map of the desktop: **what you get → what powers it → what it is for**.
The detailed project credits are further down.

### Desktop and shell

| What you get | Powered by | What it is used for |
|---|---|---|
| Base OS | **CachyOS** | Arch-based rolling base, kernels and repos |
| Desktop and window management | **Hyprland** | tiling, workspaces, animations, window rules |
| Session manager | **UWSM** | starts and supervises the Hyprland session through systemd |
| Login screen | **SDDM** + the Matugen theme | greeter that follows the current wallpaper palette |
| Top bar / notch | **Quickshell** (`bar/Bar.qml`) | clock, workspaces, tray, battery, notifications |
| App launcher | **Vicinae / Kando** | Vicinae for search and launching; Kando for the `CTRL + SPACE` radial menu |
| Quick settings | **Quickshell** (`QuickSettings.qml`) | Wi-Fi, Bluetooth, volume, audio profiles, power menu |
| Notifications | **Quickshell** `NotificationServer` | toasts, history, do-not-disturb |
| On-screen display | **Quickshell OSD** (SwayOSD optional) | volume and brightness feedback |
| Wallpaper | **hyprpaper** | applies and keeps the selected wallpaper |
| Colour theme | **Matugen + Kvantum + adw-gtk3** | one Material You palette for shell, GTK, Qt and SDDM |
| Lock screen | **hyprlock** | wallpaper lock screen with clock and password field |
| Idle handling | **hypridle** | lock at 5 min, screen off at 5.5 min |
| Auth prompts | **hyprpolkitagent** | polkit password dialogs |
| Screen sharing and portals | **xdg-desktop-portal-hyprland** | screencast, file picker and portal APIs |
| Hardware keys | **brightnessctl, wpctl, playerctl** | brightness, volume/mute and media keys |
| Fonts, icons and cursor | **Noto Sans, JetBrainsMono Nerd Font, Breeze, Bibata** | UI text, bar glyphs, icons and pointer |

### Apps and utilities

| What you get | Powered by | What it is used for |
|---|---|---|
| Music player | **Quickshell** `MusicPlayer` + **mpv + yt-dlp** | search and stream YouTube Music, queue and playback |
| Synced lyrics | **LRCLIB + Google Translate** | timed lyrics, romanised or translated lines |
| Music visualizer | **cava** | live audio bars inside the music capsule |
| Terminal | **kitty + fish** | the terminal and shell used by the session |
| File manager | **Dolphin** | file browsing, floated by a Hyprland window rule |
| Phone integration | **KDE Connect** | notifications, clipboard and file transfer from the phone |
| Screenshots | **hyprshot + Swash** | `PRINT` region capture → annotate/share |
| Screen recording | **GPU Screen Recorder** | autostarts the Flatpak recorder UI |

### Keybindings worth knowing

| Keys | Action |
|---|---|
| `SUPER + Q` | kitty |
| `SUPER + E` | Dolphin |
| `SUPER + C` | close window |
| `SUPER + F` | toggle floating |
| `SUPER + L` | lock the session |
| `SUPER + S` | toggle the `magic` scratchpad |
| `SUPER + 1…0` | switch workspace |
| `SUPER + SHIFT + 1…0` | move window to workspace |
| `CTRL + SPACE` | Kando menu |
| `PRINT` | region screenshot → Swash |

---

## Editing the desktop

Most visual tweaks start in one file:

```bash
cd ~/Projects/betterCachy
$EDITOR home/.config/quickshell/Config.qml
rsync -a home/.config/quickshell/ ~/.config/quickshell/
systemctl --user restart quickshell.service
```

`Config.qml` holds the bar geometry, animation timings and feature toggles (music
button, visualizer, notifications, battery, workspaces, tray, dock). The full list and
a reload cheat-sheet are in
[`home/.config/quickshell/README.md`](home/.config/quickshell/README.md).

Other common edits:

| Want to change | File |
|---|---|
| Bar size, notch timings, feature toggles | `home/.config/quickshell/Config.qml` |
| Bar widgets and layout | `home/.config/quickshell/bar/Bar.qml` |
| Quick settings layout | `home/.config/quickshell/bar/QuickSettings.qml` |
| Dock behaviour | `home/.config/quickshell/bar/Dock.qml` |
| Kando radial menu and theme | `home/.config/kando/menus.json`, `home/.config/kando/config.json` |
| Window rules, keybinds, animations | `home/.config/hypr/hyprland.lua` |
| Palette generation | `home/.config/matugen/config.toml` + `templates/` |
| Lock screen | `home/.config/hypr/hyprlock.conf` |
| Login screen | `home/.config/sddm-matugen/` |

After editing the repo copy, copy the changed file into `~/.config/...` (or run
`./install.sh`) and reload the service it belongs to.

---

## Restoring this desktop

On a fresh CachyOS install:

```bash
# 1a. Core stack from the CachyOS/Arch repos.
sudo pacman -S hyprland uwsm quickshell matugen hyprpaper hypridle hyprlock \
  hyprpolkitagent xdg-desktop-portal-hyprland kitty fish cava mpv yt-dlp \
  kvantum qt5ct qt6ct adw-gtk-theme breeze-icons sddm hyprshot swash \
  brightnessctl dolphin kdeconnect

# 1b. Launcher/menu packages from the AUR.
paru -S --needed vicinae-bin kando-bin

# 2. Restore the tracked desktop files (dry-run first if you like).
./install.sh -n          # preview
./install.sh             # interactive, backs up replaced files
# or: ./install.sh -y    # restore everything without prompting

# 3. Enable the session units.
systemctl --user daemon-reload
systemctl --user enable --now quickshell.service vicinae.service

# 4. Install the SDDM theme (needs sudo) and re-login.
./install.sh --system

# 5. Apply a wallpaper once to generate every palette.
~/.local/bin/theme-apply ~/Pictures/wallpaper.jpg -l
```

`install.sh` copies `home/` into `$HOME` with rsync and backs up anything it
replaces under `~/.betterCachy-backup/<timestamp>/`. To do it manually instead:

```bash
rsync -a home/ "$HOME"/
SDSM_HOME="$HOME" bash "$HOME/.config/sddm-matugen/install.sh"
```

Optional: `swayosd` if you want the extra OSD server (its unit is already in the
repo), `playerctl` if you want the media keys to work, and `gpu-screen-recorder`
(Flatpak) for the autostart recorder.

`theme-apply` is a fish script. It needs `matugen`, `hyprpaper`, `setfacl`,
`gsettings` and the two helper scripts in `~/.local/bin`.

---

## Security

This repo is a **public backup of configuration files**. Treat it that way:

- **No secrets are tracked.** Notification history, browser cookies, API tokens,
  shell history and generated palettes are excluded by `.gitignore` and stay in
  `~/.config`, `~/.local/state` or `~/.cache` on the machine.
- **The music player never stores a password.** It asks `yt-dlp` to read cookies from
  your browser at play time and keeps the exported jar under
  `~/.local/state/quickshell/...` (ignored by Git).
- **The only relaxed permission is the SDDM theme.** The installer grants the `sddm`
  user read access to `~/.config/sddm-matugen/` so the greeter can load the wallpaper
  and palette. Revoke it with
  `setfacl -b ~/.config/sddm-matugen` if you remove the theme.
- **Audit before pushing.** The commands below list anything that looks sensitive and
  any file that is tracked despite the ignore rules:

```bash
cd ~/Projects/betterCachy
git ls-files | grep -Ei 'cookie|token|secret|password|passwd|\.key$|\.pem$'
git ls-files -ci --exclude-standard      # tracked files matching .gitignore
git diff --cached                        # review exactly what will be committed
```

If a secret ever lands in a commit, rotate it first, then rewrite history with
`git filter-repo` and force-push. Deleting it in a later commit is not enough.

---

## What is deliberately not tracked

Only hand-written files are tracked. These are generated or private and stay local:

- palettes: `quickshell/colors.json`, `hypr/colors.conf`, `gtk.css`,
  `noctalia*.css`, `qt5ct|qt6ct/colors/matugen.conf`, `Kvantum/Matugen/`,
  `sddm-matugen/Colors.qml`
- wallpaper state: `hypr/hyprpaper.conf`, `hypr/lock-wall.conf`,
  `sddm-matugen/background`
- bar state: `quickshell/database.json` (notifications, dock pins, toggles)
- music state and cookies: `~/.local/state/quickshell/ytmusic-*.json`,
  `ytmusic/*-cookies.txt`
- caches, `__pycache__`, `*.bak`, AppImages, sockets and logs

`git status --ignored` shows them without ever staging them.

---

## Credits — what each project does here

betterCachy is mostly glue. The heavy lifting belongs to these upstream projects;
links point at the official upstream, not at a fork.

### Desktop foundation

| Project | Used for | Upstream |
|---|---|---|
| **CachyOS** | base distribution, kernel, repos, CachyOS fish defaults | https://cachyos.org |
| **Hyprland** | Wayland compositor, tiling, animations, window/workspace rules | https://github.com/hyprwm/Hyprland |
| **UWSM** | starts and supervises the Hyprland session through systemd user units | https://github.com/Vladimir-csp/uwsm |
| **SDDM** | display manager / login greeter | https://github.com/sddm/sddm |
| **hyprpaper** | wallpaper daemon | https://github.com/hyprwm/hyprpaper |
| **hypridle** | idle timeout → lock + DPMS | https://github.com/hyprwm/hypridle |
| **hyprlock** | lock screen | https://github.com/hyprwm/hyprlock |
| **hyprpolkitagent** | polkit authentication agent | https://github.com/hyprwm/hyprpolkitagent |
| **xdg-desktop-portal-hyprland** | screenshare, file picker and portal integration | https://github.com/hyprwm/xdg-desktop-portal-hyprland |

### Shell, launcher and OSD

| Project | Used for | Upstream |
|---|---|---|
| **Quickshell** | QML runtime behind the bar, notch, notifications, quick settings and OSD | https://quickshell.org |
| **Vicinae** | launcher / command palette running as a user service | https://github.com/vicinaehq/vicinae |
| **hyprlauncher** | declared as the `menu` program in `hyprland.lua`; no keybind currently uses it | https://github.com/hyprwm/hyprlauncher |
| **Kando** | radial / pie menu on `CTRL + SPACE` | https://kando.menu |
| **SwayOSD** | OSD server unit is kept in the repo, but the package is optional and not currently installed | https://github.com/ErikReider/SwayOSD |

### Look and feel

| Project | Used for | Upstream |
|---|---|---|
| **Matugen** | generates a Material You palette from the wallpaper and fills the templates | https://github.com/InioX/matugen |
| **Kvantum** | Qt style; `kvantum-apply` builds a `Matugen` theme from the palette | https://github.com/tsujan/Kvantum |
| **qt5ct / qt6ct** | Qt 5/6 appearance and the generated `matugen.conf` colour schemes | https://sourceforge.net/projects/qt5ct/ · https://github.com/trialuser02/qt6ct |
| **adw-gtk3** | GTK3/GTK4 theme that matches libadwaita | https://github.com/lassekongo83/adw-gtk3 |
| **Breeze icons** | icon theme | https://invent.kde.org/frameworks/breeze-icons |
| **Bibata cursor** | cursor theme (`Bibata-Modern-Ice`) | https://github.com/ful1e5/Bibata_Cursor |
| **Noto Sans** | UI font | https://fonts.google.com/noto |
| **JetBrainsMono Nerd Font** | mono font and bar glyphs | https://github.com/ryanoasis/nerd-fonts |
| **Kitty** | terminal emulator | https://github.com/kovidgoyal/kitty |
| **fish** | shell; `theme-apply` and `kvantum-apply` are fish scripts | https://fishshell.com |

### Music, media and the bar

| Project | Used for | Upstream |
|---|---|---|
| **mpv** | audio playback and the JSON IPC socket the player talks to | https://mpv.io |
| **yt-dlp** | resolves YouTube Music streams and exports browser cookies | https://github.com/yt-dlp/yt-dlp |
| **YouTube Music InnerTube** | search, home, library and queue endpoints used by `ytmusic-api.py` | https://music.youtube.com |
| **LRCLIB** | free synced-lyrics API used by `ytmusic-lyrics.sh` | https://lrclib.net |
| **Google Translate web endpoint** | romanises/translates lyric lines in `ytmusic-translate.py` | https://translate.google.com |
| **cava** | audio bars inside the music capsule (raw ASCII output) | https://github.com/karlstav/cava |
| **Quickshell services** | MPRIS, PipeWire, UPower, NetworkManager, Bluetooth, system tray | https://quickshell.org |
| **WirePlumber / PipeWire** | volume, mute and audio routing (`wpctl`) | https://pipewire.pages.freedesktop.org/wireplumber/ |

### Utilities and app integrations

| Project | Used for | Upstream |
|---|---|---|
| **Dolphin** | file manager | https://apps.kde.org/dolphin/ |
| **KDE Connect** | phone integration | https://kdeconnect.kde.org |
| **hyprshot** | screenshot capture | https://github.com/Gustash/Hyprshot |
| **Swash** | screenshot annotate/upload, receives the `PRINT` pipe | https://github.com/ItsLemmy/swash |
| **brightnessctl** | brightness media keys | https://github.com/Hummer12007/brightnessctl |
| **playerctl** | media keys (`XF86Audio*`) on the keyboard call it; install it for those bindings to work | https://github.com/altdesktop/playerctl |
| **GPU Screen Recorder** | autostarted Flatpak recorder UI | https://git.dec05eba.com/gpu-screen-recorder |
| **Shutter** | disabled autostart entry kept for reference | https://shutter-project.org |

### This repo

The QML bar, the music player, the Matugen templates and the SDDM theme are part of
betterCachy, © 2026 rishabh. Everything listed above remains the property of its
upstream authors and keeps its upstream licence.

---

## Repository layout

```
betterCachy/
├── README.md                      this file (overview + credits)
├── ARCHITECTURE.md                how the pieces fit together
├── install.sh                     restore home/ into $HOME (dry-run + backup)
├── demo.jpg                       preview image
├── home/                          files restored into $HOME
│   ├── .config/
│   │   ├── quickshell/            shell.qml, Config.qml, Colors.qml, bar/, osd/
│   │   ├── hypr/                  hyprland.lua, settings, idle and lock config
│   │   ├── matugen/               config.toml + colour templates
│   │   ├── sddm-matugen/          custom SDDM theme + install.sh
│   │   ├── systemd/user/          quickshell, vicinae and swayosd units
│   │   ├── kitty/                 terminal config + Noctalia theme
│   │   ├── gtk-3.0, gtk-4.0      toolkit settings (generated CSS excluded)
│   │   ├── qt5ct, qt6ct          Qt appearance (generated palettes excluded)
│   │   ├── Kvantum/               selected Kvantum theme name
│   │   ├── autostart/             session autostart entries
│   │   └── uwsm/                  session environment
│   └── .local/bin/                theme-apply, kvantum-apply
└── system/                        system-level SDDM theme files (installed copy)
```

## License

The betterCachy-specific code and configs in this repo are © 2026 rishabh.
Upstream projects keep their own licences; follow the links in the credits above.
