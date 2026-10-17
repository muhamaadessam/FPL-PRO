#!/usr/bin/env bash
# Renders og.html into the 1200x630 share images in public/img/ (English and
# Arabic). Needs Google Chrome. /img/* is cached as immutable, so give the
# files new names (and update the og:image tags) if they ever change.
set -euo pipefail
cd "$(dirname "$0")"

chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for lang in en ar; do
  "$chrome" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=1200,630 \
    --virtual-time-budget=3000 \
    --screenshot="$tmp/og-$lang.png" "file://$PWD/og.html#$lang" 2>/dev/null
  sips -s format jpeg -s formatOptions 86 "$tmp/og-$lang.png" \
    --out "../public/img/og-$lang.jpg" >/dev/null
done
ls -l ../public/img/og-*.jpg
