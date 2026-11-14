#!/usr/bin/env bash
# Quickshell-side adapter based on the public InnerTube flow used by
# noctalia-dev/community-plugins/yt-music (MIT); credentials remain local.
set -euo pipefail
umask 077

action=${1:-}

case "$action" in
  extract-cookies)
    browser=${2:-}
    cookie_file=${3:-}
    if [[ -z "$browser" || -z "$cookie_file" ]]; then
      echo "Missing browser or cookie destination." >&2
      exit 2
    fi

    mkdir -p "$(dirname "$cookie_file")"
    chmod 700 "$(dirname "$cookie_file")"
    raw_file="${cookie_file}.raw.$$"
    filtered_file="${cookie_file}.tmp.$$"
    error_file="${cookie_file}.err.$$"
    trap 'rm -f "$raw_file" "$filtered_file" "$error_file"' EXIT

    # yt-dlp writes the cookie jar before it tries to extract anything, so a
    # failed/unsupported extraction is not an export failure. The library page
    # is a cheap, stable URL that does not download media.
    export_rc=0
    yt-dlp --quiet --no-warnings --simulate --skip-download --no-playlist \
      --cookies-from-browser "$browser" --cookies "$raw_file" \
      "https://www.youtube.com/feed/library" >/dev/null 2>"$error_file" || export_rc=$?

    if [[ ! -s "$raw_file" ]]; then
      if grep -qiE 'decrypt|keyring|secret service' "$error_file"; then
        echo "Browser cookies could not be decrypted. Try Firefox or unlock the browser keyring." >&2
      elif grep -qiE 'database is locked|permission denied|access is denied|unable to open|failed to copy|copy.*database' "$error_file"; then
        echo "Browser cookie storage is locked. Close the selected browser and retry." >&2
      elif grep -qiE 'profile.*(not found|does not exist)|could not find.*profile|no .*profile' "$error_file"; then
        echo "Browser profile was not found. Open the selected browser once and retry." >&2
      elif [[ $export_rc -ne 0 ]]; then
        echo "Cookie export failed for ${browser}. Open YouTube Music, sign in, and retry." >&2
      else
        echo "No cookies found for ${browser}. Open YouTube Music, sign in, and retry." >&2
      fi
      exit 1
    fi

    grep -E '^#|youtube\.com|youtu\.be|youtube-nocookie\.com|ytimg\.com|googlevideo\.com|youtubeeducation\.com' \
      "$raw_file" > "$filtered_file" || true
    if ! awk -F '\t' '$0 !~ /^#/ && $6 == "SAPISID" { found=1 } END { exit !found }' "$filtered_file"; then
      echo "No authenticated YouTube Music session found in that browser. Sign in to music.youtube.com and retry." >&2
      exit 1
    fi

    chmod 600 "$filtered_file"
    mv "$filtered_file" "$cookie_file"
    echo "CONNECTED"
    ;;

  api)
    cookie_file=${2:-}
    endpoint=${3:-}
    payload=${4:-}
    if [[ -z "$cookie_file" || -z "$endpoint" || -z "$payload" || ! -s "$cookie_file" ]]; then
      echo "Connect a browser account first." >&2
      exit 2
    fi
    case "$endpoint" in
      browse|search|next|like/like|like/removelike) ;;
      *) echo "Unsupported YouTube Music endpoint." >&2; exit 2 ;;
    esac

    sapisid=$(awk -F '\t' '$0 !~ /^#/ && $6 == "SAPISID" { print $7; exit }' "$cookie_file")
    if [[ -z "$sapisid" ]]; then
      echo "The saved browser session has expired. Connect again." >&2
      exit 1
    fi
    cookie_header=$(awk -F '\t' '$0 !~ /^#/ && NF >= 7 { printf "%s%s=%s", sep, $6, $7; sep="; " }' "$cookie_file")
    timestamp=$(date +%s)
    signature=$(printf '%s %s %s' "$timestamp" "$sapisid" 'https://music.youtube.com' | sha1sum | awk '{print $1}')
    auth_header="SAPISIDHASH ${timestamp}_${signature}"

    if [[ "$endpoint" == like/* ]]; then
      curl --silent --show-error --fail --max-time 25 \
        --request POST \
        --header 'Content-Type: application/json' \
        --header 'Origin: https://music.youtube.com' \
        --header 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36' \
        --header "Authorization: ${auth_header}" \
        --header "Cookie: ${cookie_header}" \
        --data-binary "$payload" \
        --output /dev/null \
        "https://music.youtube.com/youtubei/v1/${endpoint}?key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30&prettyPrint=false"
      echo "OK"
    else
      curl --silent --show-error --fail --max-time 25 \
      --request POST \
      --header 'Content-Type: application/json' \
      --header 'Origin: https://music.youtube.com' \
      --header 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36' \
      --header "Authorization: ${auth_header}" \
      --header "Cookie: ${cookie_header}" \
      --data-binary "$payload" \
      "https://music.youtube.com/youtubei/v1/${endpoint}?key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30&prettyPrint=false"
    fi
    ;;

  *)
    echo "Usage: ytmusic-api.sh {extract-cookies|api} ..." >&2
    exit 2
    ;;
esac
