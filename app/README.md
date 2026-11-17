# bettercachy-ctl

The control center for the betterCachy desktop: a Qt Quick (QML) window with a
Python backend, living in `app/` inside the dotfiles repo.

For the desktop itself, the component credits and the full architecture, see the
repo root: [`../README.md`](../README.md) and [`../ARCHITECTURE.md`](../ARCHITECTURE.md).

## Run

    ./app/bettercachy-ctl           # opens the window (uv installs PySide6 into app/.venv on first run)

If you use plain pip instead of uv: `pip install PySide6-Essentials`, then run the
same command. If the window does not open under Wayland, try
`QT_QPA_PLATFORM=wayland ./app/bettercachy-ctl`.

## Command line

    bettercachy-ctl doctor [--json]        check tools, services, generated files, drift, packages
    bettercachy-ctl theme <wallpaper> [-l] apply a wallpaper and regenerate every palette
    bettercachy-ctl hypr                   print the Hyprland values the app manages
    bettercachy-ctl gui                    open the window explicitly (default)

The launcher skips the Qt virtualenv for `doctor` and `hypr`, so those start
instantly with the system Python.

## Pages

- **Doctor** — health checks with one-click fixes (tools, session services,
  generated files, Hyprland include, repo drift, package lists).
- **Appearance** — wallpaper picker (runs `theme-apply`), palette preview, and the
  Hyprland rounding / gaps / border / blur values the app owns.
- **Services** — start, stop, restart and read logs of the managed user services.
- **Packages** — installed vs `packages/*.txt`, with an install command for what is
  missing and a button to save the installed lists.
- **Sync** — live `~/.config` vs the repo's `home/` tree, copy changes into the
  repo, then commit and push.

## How the Hyprland settings work

The app writes `~/.config/hypr/bettercachy.lua` and appends
`require("bettercachy")` as the last line of `hyprland.lua` (a `.bak` copy is kept
the first time). It never rewrites the rest of your config. Because the require is
last, these values win over `hyprland-settings.lua`.

## Settings

`~/.config/bettercachy/settings.json` holds the wallpaper folder, last wallpaper and
repo path. Environment overrides:

- `BETTERCACHY_REPO` — point the app at a repo in another folder.
- `BETTERCACHY_HOME` — use a different home directory.
- `BETTERCACHY_DEMO=1` — use canned data for UI work.

## Layout

    bettercachy-ctl      launcher (uv → .venv, falls back to python3)
    bettercachy/         paths, settings, shell, appearance, doctor,
                         services, packages, gitsync, backend
    qml/Main.qml         window + page switcher
    qml/pages/           one file per page
    qml/components/      Btn, Card, Chip, PageHeader, SliderRow, Toggle
