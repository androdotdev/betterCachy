import argparse
import json
import sys

from . import __version__, appearance, doctor, settings
from .paths import APP_DIR


def cli_doctor(as_json: bool) -> int:
    checks = doctor.run_checks()
    if as_json:
        print(json.dumps(checks, indent=2))
    else:
        icons = {"ok": "ok  ", "warn": "warn", "fail": "FAIL"}
        group = None
        for c in checks:
            if c["group"] != group:
                group = c["group"]
                print(f"\n{group}")
            print(f"  [{icons[c['status']]}] {c['title']}" + (f"  {c['detail']}" if c["detail"] else ""))
    return 1 if any(c["status"] == "fail" for c in checks) else 0


def gui(screenshot_dir=None) -> int:
    from PySide6.QtCore import QTimer, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuickControls2 import QQuickStyle

    from .backend import Backend

    QQuickStyle.setStyle("Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("bettercachy-ctl")
    app.setDesktopFileName("bettercachy-ctl")
    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(APP_DIR / "qml/Main.qml")))
    if not engine.rootObjects():
        print("could not load qml/Main.qml", file=sys.stderr)
        return 1
    window = engine.rootObjects()[0]

    if screenshot_dir:
        from pathlib import Path
        out = Path(screenshot_dir)
        out.mkdir(parents=True, exist_ok=True)
        pages = ["doctor", "appearance", "services", "packages", "sync"]
        state = {"i": 0}

        def step():
            i = state["i"]
            if i > 0:
                window.grabWindow().save(str(out / f"{pages[i - 1]}.png"))
            if i >= len(pages):
                app.quit()
                return
            window.setProperty("pageIndex", i)
            state["i"] = i + 1
            QTimer.singleShot(900, step)

        QTimer.singleShot(1200, step)
    code = app.exec()
    # tear down QML before the Python backend so bindings do not read a dead object
    del window
    engine.deleteLater()
    app.processEvents()
    del engine, backend
    return code


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="bettercachy-ctl", description="Control the betterCachy desktop setup")
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="cmd")
    d = sub.add_parser("doctor", help="check the system and print the result")
    d.add_argument("--json", action="store_true")
    t = sub.add_parser("theme", help="apply a wallpaper and regenerate every palette")
    t.add_argument("wallpaper")
    t.add_argument("-l", "--lock", action="store_true", help="also set the lock screen wallpaper")
    sub.add_parser("hypr", help="print the effective Hyprland values this app manages")
    g = sub.add_parser("gui", help="open the window (default)")
    g.add_argument("--screenshot", metavar="DIR", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    if args.cmd == "doctor":
        return cli_doctor(args.json)
    if args.cmd == "theme":
        msg = appearance.apply_wallpaper(args.wallpaper, args.lock)
        print(msg)
        return 0 if msg == "Theme applied" else 1
    if args.cmd == "hypr":
        print(json.dumps(appearance.read_hypr(), indent=2))
        return 0
    return gui(getattr(args, "screenshot", None))


if __name__ == "__main__":
    sys.exit(main())
