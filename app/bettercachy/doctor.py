import datetime
import re

from . import appearance, gitsync, packages, services, settings
from .paths import CONFIG, HOME
from .shell import have, run

# (binaries to look for, label, required, why it matters)
TOOLS = [
    (["Hyprland", "hyprland"], "Hyprland", True, "compositor"),
    (["hyprctl"], "hyprctl", True, "reload and query Hyprland"),
    (["quickshell", "qs"], "Quickshell", True, "bar and OSD"),
    (["matugen"], "Matugen", True, "palette from wallpaper"),
    (["fish"], "fish", True, "theme-apply is a fish script"),
    (["hyprpaper"], "hyprpaper", True, "wallpaper"),
    (["mpv"], "mpv", False, "music playback"),
    (["yt-dlp"], "yt-dlp", False, "music streams"),
    (["deno", "node"], "JS runtime (deno or node)", False, "yt-dlp needs one for YouTube"),
    (["cava"], "cava", False, "bar visualizer"),
    (["curl"], "curl", False, "YouTube Music API and lyrics"),
    (["rsync"], "rsync", False, "restore home/ into $HOME"),
    (["python3"], "python3", True, "this app"),
]
GENERATED = [
    (CONFIG / "quickshell/colors.json", "Quickshell palette"),
    (CONFIG / "hypr/colors.conf", "Hyprland palette"),
    (CONFIG / "hypr/hyprpaper.conf", "Wallpaper config"),
]


def _check(cid, group, title, status, detail="", fix=None):
    return {"id": cid, "group": group, "title": title, "status": status, "detail": detail, "fix": fix}


def run_checks() -> list:
    out = []

    # ---- tools
    for names, label, required, why in TOOLS:
        ok = have(*names)
        out.append(_check(f"tool:{label}", "Tools", label,
                          "ok" if ok else ("fail" if required else "warn"),
                          why if ok else f"missing ({why})"))

    if have("yt-dlp"):
        rc, ver, _ = run(["yt-dlp", "--version"], timeout=10)
        m = re.match(r"(\d{4})\.(\d{2})\.(\d{2})", ver.strip())
        if m:
            age = (datetime.date.today() - datetime.date(*map(int, m.groups()))).days
            out.append(_check("ytdlp-age", "Tools", "yt-dlp is recent",
                              "ok" if age <= 45 else "warn",
                              f"version {ver.strip()} ({age} days old)" +
                              ("" if age <= 45 else ". YouTube breaks old builds, update it.")))

    # ---- session / services
    rc, _, _ = run(["hyprctl", "version"], timeout=5)
    out.append(_check("hypr-running", "Session", "Hyprland is running",
                      "ok" if rc == 0 else "warn", "" if rc == 0 else "not detected (fine if you run this outside the session)"))
    for svc in services.status():
        active = svc["active"]
        status = "ok" if active == "active" else ("warn" if active in ("inactive", "unknown") else "fail")
        out.append(_check(f"svc:{svc['name']}", "Session", svc["name"], status,
                          f"{active}, {svc['enabled']}",
                          None if status == "ok" else {"id": f"svc:start:{svc['name']}", "label": "Start"}))

    # ---- generated files
    last = settings.load()["last_wallpaper"]
    for path, label in GENERATED:
        ok = path.exists()
        fix = None if ok else ({"id": "theme", "label": "Run theme-apply"} if last else None)
        detail = str(path).replace(str(HOME), "~") if ok else (
            "missing" + ("" if last else ". Pick a wallpaper in Appearance first."))
        out.append(_check(f"gen:{path.name}", "Generated files", label, "ok" if ok else "fail", detail, fix))

    colors_qml = CONFIG / "quickshell/Colors.qml"
    out.append(_check("colors-qml", "Generated files", "Quickshell Colors.qml",
                      "ok" if colors_qml.exists() else "fail",
                      "theme singleton the bar imports" if colors_qml.exists() else "missing, Quickshell will not load the bar"))

    # ---- hyprland include
    if appearance.GENERATED.exists():
        ok = appearance.include_present()
        out.append(_check("hypr-include", "Config", "hyprland.lua loads bettercachy.lua",
                          "ok" if ok else "warn", "" if ok else "settings from this app are ignored until the line is added",
                          None if ok else {"id": "hypr-include", "label": "Add it"}))

    # ---- repo + packages
    rows = gitsync.drift()
    out.append(_check("drift", "Repo", "Live config matches the repo",
                      "ok" if not rows else "warn",
                      "in sync" if not rows else f"{len(rows)} file(s) differ. Open Sync to review."))
    pk = packages.compare()
    for kind, info in pk.items():
        if not info["available"]:
            continue
        n = len(info["missing"]) + len(info["extra"])
        out.append(_check(f"pkg:{kind}", "Repo", f"{kind} list matches installed",
                          "ok" if n == 0 else "warn",
                          "in sync" if n == 0 else f"{len(info['missing'])} missing, {len(info['extra'])} not listed. Open Packages."))
    return out


DEMO_CHECKS = [
    _check("tool:Hyprland", "Tools", "Hyprland", "ok", "compositor"),
    _check("tool:Quickshell", "Tools", "Quickshell", "ok", "bar and OSD"),
    _check("tool:Matugen", "Tools", "Matugen", "ok", "palette from wallpaper"),
    _check("tool:JS", "Tools", "JS runtime (deno or node)", "ok", "yt-dlp needs one for YouTube"),
    _check("ytdlp-age", "Tools", "yt-dlp is recent", "warn", "version 2026.08.21 (87 days old). YouTube breaks old builds, update it."),
    _check("svc:q", "Session", "quickshell.service", "ok", "active, enabled"),
    _check("svc:v", "Session", "vicinae.service", "warn", "inactive, enabled", {"id": "svc:start:vicinae.service", "label": "Start"}),
    _check("gen:colors.json", "Generated files", "Quickshell palette", "ok", "~/.config/quickshell/colors.json"),
    _check("colors-qml", "Generated files", "Quickshell Colors.qml", "ok", "theme singleton the bar imports"),
    _check("hypr-include", "Config", "hyprland.lua loads bettercachy.lua", "warn", "settings from this app are ignored until the line is added", {"id": "hypr-include", "label": "Add it"}),
    _check("drift", "Repo", "Live config matches the repo", "warn", "3 file(s) differ. Open Sync to review."),
    _check("pkg:pacman", "Repo", "pacman list matches installed", "ok", "in sync"),
]
