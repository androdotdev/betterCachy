import json
from pathlib import Path

from .paths import HOME, SETTINGS_FILE, default_repo

DEFAULTS = {"wallpaper_dir": "", "last_wallpaper": "", "lock": False, "repo": ""}


def load() -> dict:
    data = dict(DEFAULTS)
    try:
        data.update(json.loads(SETTINGS_FILE.read_text()))
    except Exception:  # noqa: BLE001
        pass
    if not data["repo"]:
        data["repo"] = str(default_repo())
    if not data["wallpaper_dir"]:
        for name in ("Pictures/Wallpapers", "Pictures/wallpapers", "Wallpapers", "Pictures"):
            if (HOME / name).is_dir():
                data["wallpaper_dir"] = str(HOME / name)
                break
    return data


def save(data: dict) -> None:
    SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS_FILE.write_text(json.dumps(data, indent=2))


def update(**changes) -> dict:
    data = load()
    data.update(changes)
    save(data)
    return data


def repo_path() -> Path:
    return Path(load()["repo"]).expanduser()
