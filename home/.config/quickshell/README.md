# Quickshell shell — editing guide

The whole top bar, notch, quick settings, notifications, music player, dock and OSD
run in one Quickshell process. Start here when you want to change something.

```bash
# apply any edit
systemctl --user restart quickshell.service

# watch for QML errors while you work
journalctl --user -u quickshell.service -f
```

Quickshell also hot-reloads most files when they change, but a restart is the reliable
way to pick up `Config.qml` and other singletons.

## Files

| File | What it owns |
|---|---|
| `shell.qml` | root: `Bar`, `Dock`, `OSD` — intentionally tiny |
| `Config.qml` | **all tunables and feature toggles** (start here) |
| `Colors.qml` | palette singleton, reads the generated `colors.json` |
| `bar/Bar.qml` | top panel, notch, capsule widgets, popups |
| `bar/QuickSettings.qml` | Wi-Fi, Bluetooth, audio, power menu, runtime toggles |
| `bar/NotificationList.qml` | notification history and do-not-disturb |
| `bar/CalendarPopup.qml` | clock / calendar popup |
| `bar/MusicPlayer.qml` | YouTube Music backend, search, queue, mpv, cava |
| `bar/MiniPlayer.qml` | mini now-playing card + lyrics |
| `bar/Dock.qml` | floating bottom dock |
| `bar/DockContent.qml` | dock items, pin/unpin menus |
| `bar/BarDatabase.qml` | persisted runtime state (`database.json`) |
| `osd/OSD.qml` | volume / brightness overlay |
| `bar/qmldir` | registers the reusable components as `qs.bar` |

## Config.qml

Every value has a comment in the file. The short version:

### Geometry

| Property | Default | Effect |
|---|---|---|
| `panelHeight` | `36` | height of the reserved strip at the top |
| `notchHeight` | `32` | height of the visible capsule |
| `notchRadius` | `16` | capsule corner radius |
| `notchTop` | `2` | gap between screen edge and capsule |
| `collapsedWidth` | `340` | width when only the clock/indicators are shown |
| `expandedMaxWidth` | `1180` | widest the notch may become |
| `screenEdgeMargin` | `60` | expanded width is capped to `screen - this` |
| `hiddenOffset` | `44` | how far the capsule slides away when hiding |
| `hiddenHoverHeight` | `6` | height of the strip that reveals a hidden notch |

### Timings (milliseconds)

| Property | Default | Effect |
|---|---|---|
| `hoverExpandDelay` | `45` | delay before hover expands the notch |
| `hoverCollapseDelay` | `150` | delay before it collapses after the pointer leaves |
| `notchHideDelay` | `260` | delay before auto-hide hides the capsule |
| `popupCloseDelay` | `220` | delay before a popup closes after the pointer leaves |
| `popupCloseGrace` | `400` | keep expanded after a popup closes (prevents flicker) |
| `widthDuration` | `260` | notch and music-capsule width animation |
| `revealDuration` | `240` | hide/reveal slide animation |
| `contentFadeDuration` | `140` | fade for the expanded controls |

### Feature toggles

| Property | Default | Effect |
|---|---|---|
| `hoverExpand` | `true` | expand the notch on hover |
| `musicButton` | `true` | `♫` capsule and the music players |
| `musicVisualizer` | `true` | cava bars in the capsule and compact notch |
| `notifications` | `true` | bell, history and toast popups |
| `battery` | `true` | battery percentage for laptops |
| `workspaces` | `true` | workspace capsules on the left |
| `systemTray` | `true` | tray icons |
| `mediaWidget` | `true` | now-playing capsule in the middle (MPRIS) |
| `dock` | `true` | floating bottom dock |

### Common recipes

**Hide the music button and visualizer**

```qml
property bool musicButton: false
property bool musicVisualizer: false
```

**Make the notch wider and taller**

```qml
property int collapsedWidth: 420
property int notchHeight: 34
property int notchTop: 2
```

Use `panelHeight` ≥ `notchTop + notchHeight` so the capsule is not clipped.

**Keep the bar compact (no hover expansion)**

```qml
property bool hoverExpand: false
```

Then disable auto-hide in **Quick Settings → Auto-hide**, otherwise the hidden notch
can only be revealed by hovering its small center strip.

**Slow down or speed up the animations**

```qml
property int widthDuration: 400
property int revealDuration: 350
```

## Runtime toggles vs config

Two different kinds of switches exist on purpose:

| Where | Examples | Saved where |
|---|---|---|
| `Config.qml` | geometry, timings, feature toggles | this repo |
| Quick Settings | Auto-hide, Reserve space on desktop | `~/.config/quickshell/database.json` |
| Quick Settings / bell | Do not disturb | `~/.config/quickshell/database.json` |
| Dock right-click | pinned apps, icon size | `~/.config/quickshell/database.json` |

`database.json` is personal state and is never committed. Delete it while Quickshell is
stopped to reset every runtime toggle:

```bash
systemctl --user stop quickshell.service
rm ~/.config/quickshell/database.json
systemctl --user start quickshell.service
```

## The notch and hover

- The notch expands only while the pointer is over the **capsule**, not the empty
  reserved strip around it. The sensor is `hoverSensor` in `bar/Bar.qml`.
- While hidden, a small centered strip (`hiddenHoverHeight`) reveals it.
- An open popup or the music player keeps the notch expanded.
- After a popup closes, `popupCloseGrace` keeps it expanded long enough that clicking
  the music button a second time does not collapse and re-expand the bar.

## Music player

The player is optional and can be disabled with `musicButton` / `musicVisualizer`
without deleting any code.

- Playback uses `mpv`; streams are resolved by `yt-dlp`.
- Search, home, library and queue come from `ytmusic-api.py`.
- Lyrics come from LRCLIB; translation/romanisation uses the Google Translate web
  endpoint.
- Browser cookies are exported at play time to
  `~/.local/state/quickshell/.../ytmusic/<browser>-cookies.txt`. Nothing is stored in
  this repo and no password is saved.
- If playback fails:

```bash
yt-dlp -U
journalctl --user -u quickshell.service -f
# mpv writes a log next to its socket in $XDG_RUNTIME_DIR
```

## Colours

Do not edit `Colors.qml` values by hand; they come from the wallpaper:

```bash
~/.local/bin/theme-apply ~/Pictures/wallpaper.jpg -l
```

That regenerates `~/.config/quickshell/colors.json`, which `Colors.qml` watches. Use
`Colors.primary`, `Colors.surfaceContainer`, `Colors.fg`, etc. in new QML instead of
literal colours.

## Adding a widget

1. Put `MyWidget.qml` in `bar/`.
2. Add `MyWidget 1.0 MyWidget.qml` to `bar/qmldir`.
3. Instantiate it inside the left or right `Row` in `bar/Bar.qml`.
4. Use `Colors.*` and `Config.*` values instead of hard-coded numbers.
5. Restart Quickshell and check the journal for errors.

## Troubleshooting

| Symptom | Check |
|---|---|
| Bar blank or missing | `systemctl --user status quickshell.service`; `journalctl --user -u quickshell.service -b` |
| Config edit did nothing | restart the service; singletons are not always hot-reloaded |
| Bar appears in the wrong place | `Config.panelHeight` / `notchTop` / `notchHeight` |
| Notch never expands | `Config.hoverExpand` is `false`, or a popup is holding it open |
| Notch never hides | **Quick Settings → Auto-hide**, or `Config.hoverExpand` keeps it under the pointer |
| Default purple palette | `~/.config/quickshell/colors.json` missing → run `theme-apply` |
| Music will not play | `yt-dlp -U`, browser sign-in, `mpv` installed, then read the mpv log |
| No cava bars | `cava` installed and PipeWire running; `Config.musicVisualizer` is `true` |
