#!/bin/sh
# Prepare and upload sing-box release artifacts to chinagfw mirror.
# Produces:
# - releases/sing-box-<ver>-<os>-<arch>.tar.gz
# - releases/sha256.txt
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
: "${SERVER_PATH:=/www/wwwroot/chinagfw.com/repo}"
: "${GHPROXY_BASE:=https://ghproxy.com/}"

VER=${1:-${VERSION:-}}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

get_latest_version() {
  api="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
  if have_cmd curl; then
    curl -fsL --connect-timeout 5 --max-time 15 "$api" 2>/dev/null | awk -F'"' '/"tag_name"/{print $4; exit}' | sed 's/^[vV]//'
  elif have_cmd wget; then
    wget -qO- --timeout=15 --tries=1 "$api" 2>/dev/null | awk -F'"' '/"tag_name"/{print $4; exit}' | sed 's/^[vV]//'
  else
    return 1
  fi
}

if [ -z "$VER" ]; then
  VER=$(get_latest_version || true)
fi
if [ -z "$VER" ]; then
  echo "Missing VERSION. Usage: $0 <version>" >&2
  exit 2
fi

REL_DIR="$DIR/releases"
mkdir -p "$REL_DIR"

sha256_line() {
  f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    shasum -a 256 "$f" | awk '{print $1}'
  fi
}

download_one() {
  os="$1" arch="$2"
  asset="sing-box-$VER-$os-$arch.tar.gz"
  out="$REL_DIR/$asset"
  url="https://github.com/SagerNet/sing-box/releases/download/v$VER/$asset"
  download_with_fallback "$out" \
    "${GHPROXY_BASE}${url}" \
    "$url"
}

echo "Downloading sing-box release v$VER (linux/freebsd; amd64/arm64) ..."
download_one linux amd64
download_one linux arm64
download_one freebsd amd64 || true
download_one freebsd arm64 || true

echo "Generating sha256.txt ..."
{
  for f in "$REL_DIR"/sing-box-"$VER"-*.tar.gz; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    s=$(sha256_line "$f")
    printf '%s  %s\n' "$s" "$b"
  done
} > "$REL_DIR/sha256.txt"

echo "Uploading to $SERVER_USER@$SERVER_IP:$SERVER_PATH/releases/ ..."
ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "install -d -m 755 '$SERVER_PATH/releases'"
rsync -avz "$REL_DIR/" "$SERVER_USER@$SERVER_IP:$SERVER_PATH/releases/"

echo "Done. Mirror path: $SERVER_PATH/releases/"

