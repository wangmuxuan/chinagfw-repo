#!/bin/sh
# One-click deploy to a repo web root.
# - pack sing-box.tar.gz
# - copy repo artifacts to SERVER_PATH
# - optionally reload nginx
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ -f "$DIR/lib_download.sh" ]; then
  # shellcheck disable=SC1090
  . "$DIR/lib_download.sh"
fi

if [ -f "$DIR/.env" ]; then
  # shellcheck disable=SC1090
  . "$DIR/.env"
elif [ -f "$DIR/.env.example" ]; then
  # shellcheck disable=SC1090
  . "$DIR/.env.example"
fi

: "${SERVER_IP:?missing SERVER_IP}"
: "${SERVER_USER:=root}"
: "${SERVER_PATH:=/var/www/html/repo}"
: "${DOMAIN:=chinagfw.com}"

STAMP=$(date +%Y%m%d-%H%M%S)

cd "$DIR"

if [ ! -d sing-box/.git ]; then
  echo "Missing ./sing-box repo; run sync.sh first" >&2
  exit 1
fi

if command -v download_with_fallback >/dev/null 2>&1; then
  [ -f "$DIR/geoip.db" ] || download_with_fallback "$DIR/geoip.db" \
    "${MIRROR_BASE:-https://chinagfw.com/repo}/geoip.db" \
    "https://ghproxy.com/https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db" \
    "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db"
  [ -f "$DIR/geosite.db" ] || download_with_fallback "$DIR/geosite.db" \
    "${MIRROR_BASE:-https://chinagfw.com/repo}/geosite.db" \
    "https://ghproxy.com/https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db" \
    "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db"
fi

echo "Packing sing-box.tar.gz..."
tar -czvf sing-box.tar.gz sing-box >/dev/null

echo "Backup current remote snapshot (if any)..."
ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" \
  "set -e; install -d -m 755 /opt/chinagfw/repo/backup /opt/chinagfw/repo/release '$SERVER_PATH'; \
   if [ -f '$SERVER_PATH/sing-box.tar.gz' ]; then cp -a '$SERVER_PATH/sing-box.tar.gz' /opt/chinagfw/repo/backup/sing-box.tar.gz.$STAMP || true; fi"

echo "Uploading to $SERVER_USER@$SERVER_IP:$SERVER_PATH/ ..."
rsync -avz --delete \
  --exclude '.git' \
  "$DIR/sing-box/" "$SERVER_USER@$SERVER_IP:$SERVER_PATH/sing-box/"

rsync -avz \
  "$DIR/sing-box.tar.gz" \
  "$DIR/sing-box.sh" \
  "$DIR/geoip.db" \
  "$DIR/geosite.db" \
  "$DIR/install.sh" \
  "$DIR/nginx.conf" \
  "$SERVER_USER@$SERVER_IP:$SERVER_PATH/" || true

echo "Remote post-deploy..."
ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" \
  "set -e; ls -lh '$SERVER_PATH/sing-box.tar.gz' '$SERVER_PATH/sing-box.sh' '$SERVER_PATH/install.sh' 2>/dev/null || true; \
   nginx -t >/dev/null 2>&1 && systemctl reload nginx || true"

echo "Done."
echo "Mirror base: https://$DOMAIN/repo/"
echo "Install cmd: bash <(curl -Ls https://$DOMAIN/repo/install.sh)"
