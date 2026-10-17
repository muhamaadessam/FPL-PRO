#!/usr/bin/env bash
# Assembles dist/: the static site plus the Flutter web app, both served from
# the domain root. The app's page is renamed to app.html, and the Worker serves
# it for the app routes (/login, /home, ...).
#
#   ./build.sh                     # production proxy origin
#   WEB_PROXY_ORIGIN=http://localhost:8788 ./build.sh   # for `wrangler dev`
set -euo pipefail
cd "$(dirname "$0")"

origin="${WEB_PROXY_ORIGIN:-https://fpl-pro.muhammadessam.me}"
(cd .. && flutter build web --release --base-href / \
  --dart-define=WEB_PROXY_ORIGIN="$origin")

rm -rf dist
mkdir dist
cp -R ../build/web/. dist/
mv dist/index.html dist/app.html
# Site files win where names overlap (favicon.png).
cp -R public/. dist/
