from . import settings
from .shell import have, run

DEFAULT_UNITS = ["quickshell.service", "vicinae.service", "swayosd.service"]


def managed_units() -> list:
    units = list(DEFAULT_UNITS)
    unit_dir = settings.repo_path() / "home/.config/systemd/user"
    if unit_dir.is_dir():
        for f in sorted(unit_dir.glob("*.service")):
            if f.name not in units:
                units.append(f.name)
    return units


def _state(args) -> str:
    rc, out, _ = run(["systemctl", "--user", *args], timeout=8)
    return out.strip() or ("unknown" if rc else "")


def status() -> list:
    if not have("systemctl"):
        return [{"name": u, "active": "unknown", "enabled": "unknown"} for u in managed_units()]
    return [
        {"name": u, "active": _state(["is-active", u]), "enabled": _state(["is-enabled", u])}
        for u in managed_units()
    ]


def action(name: str, verb: str) -> str:
    if verb not in ("start", "stop", "restart", "enable", "disable"):
        return f"unsupported action: {verb}"
    rc, out, err = run(["systemctl", "--user", verb, name], timeout=20)
    return f"{verb} {name}: " + ("ok" if rc == 0 else (err.strip() or out.strip() or f"exit {rc}"))


def logs(name: str, lines: int = 80) -> str:
    rc, out, err = run(["journalctl", "--user", "-u", name, "-n", str(lines), "--no-pager"], timeout=10)
    return out if out.strip() else (err.strip() or "no log output")
