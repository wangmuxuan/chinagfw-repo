#!/bin/sh
# One-liner installer entrypoint for users in China.
set -eu

: "${MIRROR_BASE:=https://chinagfw.com/repo}"
: "${GHPROXY_BASE:=https://ghproxy.com/}"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

download_with_fallback() {
  dest="$1"; shift
  dest_dir=${dest%/*}
  [ "$dest_dir" = "$dest" ] && dest_dir='.'
  [ -d "$dest_dir" ] || mkdir -p "$dest_dir"
  tmp="$dest.tmp.$$"
  rm -f "$tmp"
  for url in "$@"; do
    if have_cmd curl; then
      if curl -fL --connect-timeout 5 --max-time 15 --retry 0 -o "$tmp" "$url" >/dev/null 2>&1; then
        mv -f "$tmp" "$dest"
        return 0
      fi
      if curl -fL --connect-timeout 10 --max-time 180 \
        --retry 5 --retry-delay 1 --retry-all-errors \
        -o "$tmp" "$url"; then
        mv -f "$tmp" "$dest"
        return 0
      fi
    elif have_cmd wget; then
      if wget -T 15 -t 1 -O "$tmp" "$url" >/dev/null 2>&1; then
        mv -f "$tmp" "$dest"
        return 0
      fi
      if wget -T 180 -t 5 -O "$tmp" "$url"; then
        mv -f "$tmp" "$dest"
        return 0
      fi
    else
      echo "Need curl or wget" >&2
      return 127
    fi
    rm -f "$tmp" 2>/dev/null || true
  done
  rm -f "$tmp"
  return 1
}

tmpdir=${TMPDIR:-/tmp}/sing-box-install.$$
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

echo "Downloading sing-box.sh with fallback..."
download_with_fallback "$tmpdir/sing-box.sh" \
  "$MIRROR_BASE/sing-box.sh" \
  "${GHPROXY_BASE}https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh" \
  "https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh"

chmod +x "$tmpdir/sing-box.sh"

# upstream sing-box.sh requires bash (uses arrays)
if have_cmd bash; then
  export MIRROR_RELEASES="${MIRROR_RELEASES:-${MIRROR_BASE%/}/releases}"
  exec bash "$tmpdir/sing-box.sh" "$@"
fi

echo "bash not found. Please install bash first (e.g. apt/yum/apk install bash)." >&2
exit 127
