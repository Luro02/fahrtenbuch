#!/bin/sh -eu

flutter build web --release --dart-define API_URL=${API_URL:-}

chmod -R 755 /usr/share/nginx/html
cp -r /app/build/web/* /usr/share/nginx/html/

nginx -g "daemon off;"