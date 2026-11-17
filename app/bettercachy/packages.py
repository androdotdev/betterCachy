from . import settings
from .shell import have, run

FILES = {
    "pacman": ("pacman-explicit.txt", ["pacman", "-Qqe"]),
    "aur": ("pacman-foreign.txt", ["pacman", "-Qqm"]),
    "flatpak": ("flatpak.txt", ["flatpak", "list", "--app", "--columns=application"]),
}


def _read_list(path) -> list:
    try:
        return sorted({l.strip() for l in path.read_text().splitlines() if l.strip()})
    except OSError:
        return []


def installed(kind: str):
    """Installed packages of a kind, or None if that tool is missing."""
    cmd = FILES[kind][1]
    if not have(cmd[0]):
        return None
    rc, out, _ = run(cmd, timeout=30)
    if rc != 0:
        return None
    return sorted({l.strip() for l in out.splitlines() if l.strip()})


def compare() -> dict:
    repo = settings.repo_path() / "packages"
    result = {}
    for kind, (filename, _) in FILES.items():
        listed = _read_list(repo / filename)
        live = installed(kind)
        if live is None:
            result[kind] = {"available": False, "listed": len(listed), "installed": 0, "missing": [], "extra": []}
            continue
        result[kind] = {
            "available": True,
            "listed": len(listed),
            "installed": len(live),
            "missing": sorted(set(listed) - set(live)),
            "extra": sorted(set(live) - set(listed)),
        }
    return result


def install_command(info: dict) -> str:
    parts = []
    if info.get("pacman", {}).get("missing"):
        parts.append("sudo pacman -S --needed " + " ".join(info["pacman"]["missing"]))
    if info.get("aur", {}).get("missing"):
        parts.append("paru -S --needed " + " ".join(info["aur"]["missing"]))
    if info.get("flatpak", {}).get("missing"):
        parts.append("flatpak install -y " + " ".join(info["flatpak"]["missing"]))
    return "\n".join(parts)


def write_lists() -> str:
    repo = settings.repo_path() / "packages"
    repo.mkdir(parents=True, exist_ok=True)
    written = []
    for kind, (filename, _) in FILES.items():
        live = installed(kind)
        if live is None:
            continue
        (repo / filename).write_text("\n".join(live) + "\n")
        written.append(f"{filename} ({len(live)})")
    return "Updated " + ", ".join(written) if written else "No package tools found"
