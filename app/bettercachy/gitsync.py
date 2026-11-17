import filecmp
import os
from pathlib import Path

from . import settings
from .paths import HOME
from .shell import run

# Live folders compared against the repo's home/ tree. Only the hand-written
# desktop files live here; generated palettes, caches and personal state do not.
WATCH_DIRS = [
    ".config/quickshell", ".config/hypr", ".config/matugen", ".config/systemd/user",
    ".config/kitty", ".config/sddm-matugen", ".config/uwsm",
    ".config/gtk-3.0", ".config/gtk-4.0", ".config/qt5ct", ".config/qt6ct",
    ".config/Kvantum", ".config/autostart", ".local/bin",
]
# Generated at theme time, never tracked.
IGNORE_PARTS = {"__pycache__", "Cache", "GPUCache", ".cache", "Matugen", "SuaveDark"}
IGNORE_NAMES = {
    "colors.json", "colors.conf", "hyprpaper.conf", "lock-wall.conf", "background",
    "gtk.css", "bettercachy.lua", "hyprland.lua.bak",
    "database.json", "matugen.conf", "noctalia.css", "noctalia-extensions.css",
    "thumbnail.png",
}
# Generated files whose name is also used by a tracked source file.
IGNORE_REL = {
    ".config/sddm-matugen/Colors.qml",
    ".config/sddm-matugen/theme/Colors.qml",
}


def _ignored(path: Path) -> bool:
    return (
        path.name in IGNORE_NAMES
        or path.suffix in (".log", ".AppImage")
        or ".bak" in path.name
        or str(path) in IGNORE_REL
        or bool(IGNORE_PARTS & set(path.parts))
    )


def drift() -> list:
    repo_home = settings.repo_path() / "home"
    rows = []
    if not repo_home.is_dir():
        return rows
    seen = set()
    for rel_dir in WATCH_DIRS:
        base = repo_home / rel_dir
        if base.is_dir():
            for root, _, files in os.walk(base):
                for name in files:
                    repo_file = Path(root) / name
                    if repo_file.is_symlink():
                        continue
                    rel = repo_file.relative_to(repo_home)
                    if _ignored(rel):
                        continue
                    seen.add(rel)
                    live = HOME / rel
                    if not live.exists():
                        rows.append({"path": str(rel), "status": "missing", "select": False})
                    elif not filecmp.cmp(repo_file, live, shallow=False):
                        rows.append({"path": str(rel), "status": "changed", "select": True})
        live_base = HOME / rel_dir
        if live_base.is_dir():
            for root, _, files in os.walk(live_base):
                for name in files:
                    live_file = Path(root) / name
                    if live_file.is_symlink():
                        continue
                    rel = live_file.relative_to(HOME)
                    if rel in seen or _ignored(rel):
                        continue
                    if not (repo_home / rel).exists():
                        rows.append({"path": str(rel), "status": "new", "select": True})
        if len(rows) > 400:
            break
    rows.sort(key=lambda r: (r["status"], r["path"]))
    return rows


def save_to_repo(paths: list) -> str:
    repo_home = settings.repo_path() / "home"
    copied = 0
    for rel in paths:
        live = HOME / rel
        if live.is_file():
            target = repo_home / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(live.read_bytes())
            target.chmod(live.stat().st_mode & 0o777)
            copied += 1
    return f"Copied {copied} file(s) into the repo"


def info() -> dict:
    repo = settings.repo_path()
    if not (repo / ".git").exists():
        return {"ok": False, "branch": "", "last": "not a git repo: " + str(repo), "dirty": 0, "log": ""}
    _, branch, _ = run(["git", "-C", str(repo), "rev-parse", "--abbrev-ref", "HEAD"], timeout=8)
    _, last, _ = run(["git", "-C", str(repo), "log", "-1", "--format=%h %s (%cr)"], timeout=8)
    _, status, _ = run(["git", "-C", str(repo), "status", "--porcelain"], timeout=10)
    _, log, _ = run(["git", "-C", str(repo), "log", "-8", "--format=%h  %s  (%cr)"], timeout=8)
    return {
        "ok": True, "branch": branch.strip(), "last": last.strip(),
        "dirty": len([l for l in status.splitlines() if l.strip()]), "log": log.strip(),
    }


def commit(message: str) -> str:
    repo = str(settings.repo_path())
    message = message.strip() or "Update from bettercachy-ctl"
    rc, _, err = run(["git", "-C", repo, "add", "-A"], timeout=20)
    if rc != 0:
        return "git add failed: " + err.strip()
    rc, out, err = run(["git", "-C", repo, "commit", "-m", message], timeout=20)
    if rc == 0:
        return "Committed: " + message
    return "Nothing to commit" if "nothing to commit" in (out + err) else "git commit failed: " + (err.strip() or out.strip())


def push() -> str:
    rc, out, err = run(["git", "-C", str(settings.repo_path()), "push"], timeout=60)
    return "Pushed" if rc == 0 else "git push failed: " + (err.strip() or out.strip())[-250:]
