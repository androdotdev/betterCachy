"""QObject bridge between the QML UI and the backend modules."""
import threading

from PySide6.QtCore import Property, QObject, Signal, Slot

from . import appearance, doctor, gitsync, packages, services, settings
from .paths import DEMO, HOME, SETTINGS_FILE  # noqa: F401
from .shell import run

DEMO_WALLS = [{"path": "", "name": n} for n in ("forest-mist", "night-city", "dunes", "aurora", "peaks", "koi")]


class Backend(QObject):
    changed = Signal(str)          # name of the property that changed
    _task_done = Signal(str, object)

    def __init__(self):
        super().__init__()
        self._data = {
            "palette": appearance.palette(), "checks": [], "wallpapers": [],
            "hypr": appearance.read_hypr(), "services": [], "serviceLog": "",
            "packages": {}, "installCommand": "", "drift": [], "git": {},
            "toast": "", "busy": "", "wallpaperDir": "", "currentWallpaper": "",
            "lock": False, "repo": "", "hyprInclude": True,
        }
        s = settings.load()
        self._data.update(wallpaperDir=s["wallpaper_dir"], currentWallpaper=s["last_wallpaper"],
                          lock=s["lock"], repo=s["repo"], hyprInclude=appearance.include_present())
        self._task_done.connect(self._finish)
        self._handlers = {}

    # ---------- generic property plumbing ----------
    def _get(self, key):
        return self._data[key]

    def _set(self, key, value):
        self._data[key] = value
        self.changed.emit(key)

    palette = Property("QVariant", lambda s: s._get("palette"), notify=changed)
    checks = Property("QVariant", lambda s: s._get("checks"), notify=changed)
    wallpapers = Property("QVariant", lambda s: s._get("wallpapers"), notify=changed)
    hypr = Property("QVariant", lambda s: s._get("hypr"), notify=changed)
    serviceList = Property("QVariant", lambda s: s._get("services"), notify=changed)
    serviceLog = Property(str, lambda s: s._get("serviceLog"), notify=changed)
    pkgInfo = Property("QVariant", lambda s: s._get("packages"), notify=changed)
    installCommand = Property(str, lambda s: s._get("installCommand"), notify=changed)
    drift = Property("QVariant", lambda s: s._get("drift"), notify=changed)
    git = Property("QVariant", lambda s: s._get("git"), notify=changed)
    toast = Property(str, lambda s: s._get("toast"), notify=changed)
    busy = Property(str, lambda s: s._get("busy"), notify=changed)
    wallpaperDir = Property(str, lambda s: s._get("wallpaperDir"), notify=changed)
    currentWallpaper = Property(str, lambda s: s._get("currentWallpaper"), notify=changed)
    lock = Property(bool, lambda s: s._get("lock"), notify=changed)
    repo = Property(str, lambda s: s._get("repo"), notify=changed)
    hyprInclude = Property(bool, lambda s: s._get("hyprInclude"), notify=changed)

    # ---------- background tasks ----------
    def _async(self, label, fn, done):
        self._set("busy", label)

        def work():
            try:
                result = fn()
            except Exception as error:  # noqa: BLE001
                result = error
            self._task_done.emit(label, (done, result))

        threading.Thread(target=work, daemon=True).start()

    def _finish(self, label, payload):
        done, result = payload
        if self._data["busy"] == label:
            self._set("busy", "")
        if isinstance(result, Exception):
            self._set("toast", f"{label} failed: {result!r}")
            return
        done(result)

    def _toast(self, text):
        self._set("toast", "")
        self._set("toast", text)

    @Slot()
    def clearToast(self):
        self._set("toast", "")

    # ---------- doctor ----------
    @Slot()
    def runDoctor(self):
        self._async("Checking system", (lambda: doctor.DEMO_CHECKS) if DEMO else doctor.run_checks,
                    lambda r: self._set("checks", r))

    @Slot(str)
    def applyFix(self, fix_id):
        def fix():
            if fix_id == "theme":
                last = settings.load()["last_wallpaper"]
                return appearance.apply_wallpaper(last, settings.load()["lock"]) if last else "No wallpaper chosen yet"
            if fix_id == "hypr-include":
                return appearance.ensure_include() or "Already present"
            if fix_id.startswith("svc:"):
                _, verb, name = fix_id.split(":", 2)
                return services.action(name, verb)
            return "Unknown fix"

        def done(msg):
            self._toast(msg)
            self.runDoctor()

        self._async("Applying fix", fix, done)

    # ---------- appearance ----------
    @Slot()
    def loadAppearance(self):
        s = settings.load()
        if DEMO:
            self._set("wallpapers", DEMO_WALLS)
        else:
            self._async("Scanning wallpapers", lambda: appearance.list_wallpapers(s["wallpaper_dir"]),
                        lambda r: self._set("wallpapers", r))
        self._set("hypr", appearance.read_hypr())
        self._set("palette", appearance.palette())
        self._set("hyprInclude", appearance.include_present())

    @Slot(str)
    def setWallpaperDir(self, folder):
        settings.update(wallpaper_dir=folder)
        self._set("wallpaperDir", folder)
        self.loadAppearance()

    @Slot(str, bool)
    def applyWallpaper(self, path, lock):
        def done(msg):
            self._set("currentWallpaper", path if msg == "Theme applied" else self._data["currentWallpaper"])
            self._set("lock", lock)
            self._set("palette", appearance.palette())
            self._toast(msg)

        self._async("Applying theme", lambda: appearance.apply_wallpaper(path, lock), done)

    @Slot("QVariant")
    def applyHypr(self, values):
        vals = {k: (bool(v) if k == "blur_enabled" else int(v)) for k, v in dict(values).items()}

        def done(msg):
            self._set("hypr", appearance.read_hypr())
            self._set("hyprInclude", appearance.include_present())
            self._toast(msg)

        self._async("Applying Hyprland settings", lambda: appearance.write_hypr(vals), done)

    # ---------- services ----------
    @Slot()
    def refreshServices(self):
        if DEMO:
            self._set("services", [
                {"name": "quickshell.service", "active": "active", "enabled": "enabled"},
                {"name": "vicinae.service", "active": "inactive", "enabled": "enabled"},
                {"name": "swayosd.service", "active": "active", "enabled": "enabled"}])
            return
        self._async("Reading services", services.status, lambda r: self._set("services", r))

    @Slot(str, str)
    def serviceAction(self, name, verb):
        def done(msg):
            self._toast(msg)
            self.refreshServices()

        self._async(f"{verb} {name}", lambda: services.action(name, verb), done)

    @Slot(str)
    def loadLogs(self, name):
        if DEMO:
            self._set("serviceLog", "Nov 16 09:12:01 quickshell[1042]: Reloaded config\nNov 16 09:12:02 quickshell[1042]: Loaded bar/MiniPlayer.qml")
            return
        self._async("Reading logs", lambda: services.logs(name), lambda r: self._set("serviceLog", r))

    # ---------- packages ----------
    @Slot()
    def refreshPackages(self):
        if DEMO:
            info = {"pacman": {"available": True, "listed": 228, "installed": 231, "missing": ["cava"], "extra": ["deno", "ffmpegthumbnailer", "jq"]},
                    "aur": {"available": True, "listed": 3, "installed": 3, "missing": [], "extra": []},
                    "flatpak": {"available": True, "listed": 3, "installed": 3, "missing": [], "extra": []}}
            self._set("packages", info)
            self._set("installCommand", packages.install_command(info))
            return

        def done(info):
            self._set("packages", info)
            self._set("installCommand", packages.install_command(info))

        self._async("Comparing packages", packages.compare, done)

    @Slot()
    def writePackageLists(self):
        def done(msg):
            self._toast(msg)
            self.refreshPackages()

        self._async("Writing package lists", packages.write_lists, done)

    # ---------- sync ----------
    @Slot()
    def refreshSync(self):
        if DEMO:
            self._set("drift", [
                {"path": ".config/quickshell/bar/MusicPlayer.qml", "status": "changed", "select": True},
                {"path": ".config/quickshell/bar/MiniPlayer.qml", "status": "new", "select": True},
                {"path": ".config/quickshell/Colors.qml", "status": "new", "select": True}])
            self._set("git", {"ok": True, "branch": "main", "last": "4cbac91 fixed install.sh (2 days ago)", "dirty": 0,
                              "log": "4cbac91  fixed install.sh  (2 days ago)\n9a1be02  quickshell player redesign  (5 days ago)"})
            return

        def work():
            return gitsync.drift(), gitsync.info()

        def done(r):
            self._set("drift", r[0])
            self._set("git", r[1])

        self._async("Comparing live config with the repo", work, done)

    @Slot("QVariant")
    def saveToRepo(self, paths):
        def done(msg):
            self._toast(msg)
            self.refreshSync()

        self._async("Copying files", lambda: gitsync.save_to_repo(list(paths)), done)

    @Slot(str)
    def commit(self, message):
        def done(msg):
            self._toast(msg)
            self.refreshSync()

        self._async("Committing", lambda: gitsync.commit(message), done)

    @Slot()
    def push(self):
        self._async("Pushing", gitsync.push, lambda msg: (self._toast(msg), self.refreshSync()))
