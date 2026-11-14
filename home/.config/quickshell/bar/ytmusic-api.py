#!/usr/bin/env python3
"""Small YouTube Music InnerTube helper used by MusicPlayer.qml."""
import http.cookiejar
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

CLIENT_NAME = "WEB_REMIX"
CLIENT_VERSION = "1.20240813.01.00"
BASE_URL = "https://music.youtube.com/youtubei/v1/"

BROWSERS = {
    "vivaldi": "vivaldi",
    "firefox": "firefox",
    "chromium": "chromium",
    "chrome": "chrome",
    "brave": "brave",
    "edge": "edge",
    "opera": "opera",
}

def fail(message, code=1):
    print(message, file=sys.stderr)
    raise SystemExit(code)

def extract_cookies(browser, cookie_path):
    browser = BROWSERS.get(browser.lower())
    if not browser:
        fail("Unsupported browser: " + browser)
    if not shutil_which("yt-dlp"):
        fail("yt-dlp is required to extract browser cookies. Install yt-dlp first.")
    parent = os.path.dirname(os.path.abspath(cookie_path))
    os.makedirs(parent, exist_ok=True)
    # yt-dlp reads the browser's cookie store and exports Netscape cookies.
    cmd = [
        "yt-dlp", "--cookies-from-browser", browser,
        "--cookies", cookie_path, "--skip-download",
        "https://music.youtube.com/",
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        fail(detail or "Could not extract browser cookies.")
    if not os.path.isfile(cookie_path) or os.path.getsize(cookie_path) == 0:
        fail("Cookie extraction completed but no cookie file was created.")
    # Verify the export contains YouTube cookies, without printing cookie values.
    with open(cookie_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    if "youtube.com" not in content and ".youtube.com" not in content:
        fail("No YouTube cookies found. Sign in to music.youtube.com in that browser first.")
    print("Cookies exported successfully.")

def shutil_which(name):
    from shutil import which
    return which(name)

def api(cookie_path, endpoint, payload_text):
    if not os.path.isfile(cookie_path):
        fail("YouTube Music cookies not found. Connect your browser account first.")
    try:
        with open(cookie_path, "r", encoding="utf-8") as f:
            cookie_header_lines = [line for line in f if line.strip() and not line.startswith("#")]
    except OSError as e:
        fail("Cannot read cookie file: " + str(e))

    jar = http.cookiejar.MozillaCookieJar()
    try:
        jar.load(cookie_path, ignore_discard=True, ignore_expires=True)
    except Exception as e:
        fail("Invalid Netscape cookie file: " + str(e))
    if not list(jar):
        fail("Cookie file is empty. Reconnect your browser account.")

    try:
        payload = json.loads(payload_text)
    except json.JSONDecodeError as e:
        fail("Invalid request JSON: " + str(e))
    if not isinstance(payload, dict):
        fail("Request payload must be a JSON object.")

    # Keep the caller's context intact; ensure WEB_REMIX is used for Music.
    context = payload.setdefault("context", {})
    client = context.setdefault("client", {})
    client.setdefault("clientName", CLIENT_NAME)
    client.setdefault("clientVersion", CLIENT_VERSION)
    client.setdefault("hl", "en")
    client.setdefault("gl", "US")

    endpoint = endpoint.lstrip("/")
    if not endpoint or any(part in endpoint for part in ("..", "?", "#")):
        fail("Invalid InnerTube endpoint.")
    url = BASE_URL + endpoint + "?" + urllib.parse.urlencode({"prettyPrint": "false"})

    request = urllib.request.Request(
        url,
        data=json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Origin": "https://music.youtube.com",
            "Referer": "https://music.youtube.com/",
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36",
            "X-YouTube-Client-Name": "67",
            "X-YouTube-Client-Version": client.get("clientVersion", CLIENT_VERSION),
        },
        method="POST",
    )
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    try:
        with opener.open(request, timeout=25) as response:
            body = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        fail("YouTube Music API HTTP %s: %s" % (e.code, detail[:1200]))
    except Exception as e:
        fail("YouTube Music API request failed: " + str(e))
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        fail("YouTube Music returned invalid JSON: " + body[:500])
    sys.stdout.write(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n")

def main():
    if len(sys.argv) < 2:
        fail("Usage: ytmusic-api.sh api COOKIE_PATH ENDPOINT PAYLOAD | extract-cookies BROWSER COOKIE_PATH", 2)
    command = sys.argv[1]
    if command == "extract-cookies":
        if len(sys.argv) != 4:
            fail("Usage: ytmusic-api.sh extract-cookies BROWSER COOKIE_PATH", 2)
        extract_cookies(sys.argv[2], sys.argv[3])
    elif command == "api":
        if len(sys.argv) != 5:
            fail("Usage: ytmusic-api.sh api COOKIE_PATH ENDPOINT PAYLOAD", 2)
        api(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        fail("Unknown command: " + command, 2)

if __name__ == "__main__":
    main()
