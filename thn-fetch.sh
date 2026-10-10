#!/usr/bin/env bash
set -euo pipefail

FEED_URL="https://thehackernews.com/feeds/posts/default?alt=json&max-results=30"
USER_AGENT="omarchy-hackernews/0.1 (+https://omarchy.org)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-hackernews"
CACHE_FILE="$CACHE_DIR/feed.json"

max_items="${1:-12}"
case "$max_items" in
  '' | *[!0-9]*) max_items=12 ;;
esac
(( max_items < 1 )) && max_items=1
(( max_items > 30 )) && max_items=30

fetch_feed() {
  curl -fsSL \
    --proto '=https' --proto-redir '=https' \
    --tlsv1.2 \
    --max-time 20 --retry 2 --retry-delay 1 --retry-connrefused \
    -A "$USER_AGENT" -H 'Accept: application/json' \
    "$FEED_URL"
}

normalize() {
  jq -c \
    --arg src "The Hacker News" \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson max "$max_items" \
    -f "$SCRIPT_DIR/normalize.jq"
}

mkdir -p "$CACHE_DIR"

if raw="$(fetch_feed 2>/dev/null)" && out="$(printf '%s' "$raw" | normalize 2>/dev/null)"; then
  tmp="$CACHE_FILE.$$.tmp"
  if printf '%s' "$out" > "$tmp"; then
    mv -f "$tmp" "$CACHE_FILE"
  else
    rm -f "$tmp"
  fi
  printf '%s' "$out"
  exit 0
fi

if [[ -f "$CACHE_FILE" ]] && out="$(jq -c '.stale = true' "$CACHE_FILE" 2>/dev/null)"; then
  printf '%s' "$out"
  exit 0
fi

printf '%s' '{"ok":false,"stale":true,"source":"The Hacker News","updated":"","items":[],"error":"offline"}'
exit 0
