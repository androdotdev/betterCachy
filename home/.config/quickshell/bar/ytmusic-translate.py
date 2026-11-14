#!/usr/bin/env python3
"""Romanize (Hinglish) or translate (English) lyric lines.

usage: ytmusic-translate.py {roman|en} '<json array of strings>'
prints a JSON array of the same length. Exits 1 when nothing could be converted.
Uses the public Google Translate web endpoint, one request per line, no key.
"""
import json
import re
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

mode = sys.argv[1] if len(sys.argv) > 1 else "roman"
lines = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []
lines = [str(x) for x in lines][:240]
NON_ASCII = re.compile(r"[^\x00-\x7f]")
last_error = ["no request made"]


def wanted(line):
    text = line.strip()
    if not text or text == "\u266a":
        return False
    return mode == "en" or bool(NON_ASCII.search(text))


def convert(line):
    """returns (text, ok)"""
    if not wanted(line):
        return line, None
    query = urllib.parse.urlencode(
        {"client": "gtx", "sl": "auto", "tl": "en", "dt": ["t", "rm"], "q": line}, doseq=True
    )
    request = urllib.request.Request(
        "https://translate.googleapis.com/translate_a/single?" + query,
        headers={"User-Agent": "Mozilla/5.0"},
    )
    for _ in range(2):
        try:
            with urllib.request.urlopen(request, timeout=8) as response:
                data = json.load(response)
            segments = [s for s in (data[0] or []) if isinstance(s, list)]
            if mode == "en":
                out = "".join(s[0] for s in segments if isinstance(s[0], str))
            else:
                # romanization rides in a segment whose first item is null; take the
                # first Latin-only string in it (index differs between responses)
                parts = []
                for s in segments:
                    if s[0] is not None:
                        continue
                    for item in s[1:]:
                        if isinstance(item, str) and item.strip() and not NON_ASCII.search(item):
                            parts.append(item)
                            break
                out = " ".join(parts)
            out = out.strip()
            if out:
                return out, True
            last_error[0] = "response had no usable text: " + json.dumps(data, ensure_ascii=False)[:300]
        except Exception as error:
            last_error[0] = repr(error)
    return line, False


with ThreadPoolExecutor(max_workers=6) as pool:
    results = list(pool.map(convert, lines))

if not any(ok for _, ok in results):
    print("conversion failed: " + last_error[0], file=sys.stderr)
    sys.exit(1)
print(json.dumps([text for text, _ in results], ensure_ascii=False))
