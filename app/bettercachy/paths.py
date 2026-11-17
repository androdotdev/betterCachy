import os
from pathlib import Path

HOME = Path(os.environ.get("BETTERCACHY_HOME", Path.home()))
CONFIG = HOME / ".config"
APP_DIR = Path(__file__).resolve().parents[1]
STATE_DIR = CONFIG / "bettercachy"
SETTINGS_FILE = STATE_DIR / "settings.json"
DEMO = os.environ.get("BETTERCACHY_DEMO") == "1"


def default_repo() -> Path:
    """The repo is the folder that contains app/ (this app ships inside it)."""
    env = os.environ.get("BETTERCACHY_REPO")
    if env:
        return Path(env).expanduser()
    candidate = APP_DIR.parent
    if (candidate / "home").is_dir():
        return candidate
    for name in ("bettercachy", "betterCachy", "dotfiles"):
        guess = HOME / name
        if (guess / "home").is_dir():
            return guess
    return candidate
