#!/usr/bin/env bash
# Assembles dist/: the static site plus the Flutter web app, both served from
# the domain root. The app's page is renamed to app.html, and the Worker serves
# it for the app routes (/login, /home, ...).
#
#   ./build.sh                     # production proxy origin
#   WEB_PROXY_ORIGIN=http://localhost:8788 ./build.sh   # for `wrangler dev`
#
# ADSENSE_CLIENT defaults to our publisher ID and also fills ads.txt. Ads show
# once ADSENSE_SLOT_BANNER or ADSENSE_SLOT_RAIL is set; ADSENSE_TEST=true
# requests test ads.
set -euo pipefail
cd "$(dirname "$0")"

origin="${WEB_PROXY_ORIGIN:-https://fpl-pro.muhammadessam.me}"
client="${ADSENSE_CLIENT:-ca-pub-7614735907221714}"
(cd .. && flutter build web --release --base-href / \
  --dart-define=WEB_PROXY_ORIGIN="$origin" \
  --dart-define=ADSENSE_CLIENT="$client" \
  --dart-define=ADSENSE_SLOT_BANNER="${ADSENSE_SLOT_BANNER:-}" \
  --dart-define=ADSENSE_SLOT_RAIL="${ADSENSE_SLOT_RAIL:-}" \
  --dart-define=ADSENSE_TEST="${ADSENSE_TEST:-false}")

rm -rf dist
mkdir dist
cp -R ../build/web/. dist/
mv dist/index.html dist/app.html
# Site files win where names overlap (favicon.png).
cp -R public/. dist/

if [[ -n "$client" ]]; then
  echo "google.com, ${client#ca-}, DIRECT, f08c47fec0942fa0" > dist/ads.txt
fi
