#!/usr/bin/env sh
set -eu

flutter build web --release --dart-define API_URL=$API_URL

chmod -R 755 /srv
cp -r /app/build/web/* /srv/

caddy run
