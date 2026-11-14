#!/usr/bin/env bash
# Synced lyrics lookup against lrclib.net (free, no key).
# Prints one JSON object (exact match) or a JSON array (search results).
# Prints nothing when there is no match.
set -u
title=${1:-}
artist=${2:-}
duration=${3:-0}
[[ -z "$title" ]] && exit 2

ua='quickshell-ytmusic/1.0 (github.com/androdotdev/bettercachy)'
fetch() { curl --silent --fail --get --max-time 10 --user-agent "$ua" "$@"; }

args=(--data-urlencode "track_name=${title}" --data-urlencode "artist_name=${artist}")
if [[ "$duration" =~ ^[0-9]+$ && "$duration" -gt 0 ]]; then
  args+=(--data-urlencode "duration=${duration}")
fi

if out=$(fetch "https://lrclib.net/api/get" "${args[@]}") && [[ -n "$out" ]]; then
  printf '%s' "$out"
  exit 0
fi

if out=$(fetch "https://lrclib.net/api/search" --data-urlencode "q=${title} ${artist}") && [[ -n "$out" ]]; then
  printf '%s' "$out"
fi
exit 0
