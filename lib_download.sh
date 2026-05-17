#!/bin/sh
# POSIX download helper with China-friendly fallback.
set -eu

: "${MIRROR_BASE:=https://chinagfw.com/repo}"
: "${GHPROXY_BASE:=https://ghproxy.com/}"

have_cmd() { command -v "$1" >/dev/null 2>&1; }
_log() { printf '%s\n' "$*" >&2; }

# download_with_fallback DEST URL...
# - Uses curl or wget
# - Retries each URL up to 3 times
# - Writes to DEST. Parent dirs are created.
download_with_fallback() {
  dest="$1"; shift
  [ $# -ge 1 ] || { _log "download_with_fallback: missing url"; return 2; }

  dest_dir=${dest%/*}
  [ "$dest_dir" = "$dest" ] && dest_dir='.'
  [ -d "$dest_dir" ] || mkdir -p "$dest_dir"

  tmp="$dest.tmp.$$"
  rm -f "$tmp"

  for url in "$@"; do
    i=1
    while [ "$i" -le 3 ]; do
      _log "Downloading ($i/3): $url"
      if have_cmd curl; then
        if curl -fL --connect-timeout 10 --max-time 180 \
          --retry 2 --retry-delay 1 --retry-all-errors \
          -o "$tmp" "$url"; then
          mv -f "$tmp" "$dest"
          return 0
        fi
      elif have_cmd wget; then
        if wget -T 180 -t 3 -O "$tmp" "$url"; then
          mv -f "$tmp" "$dest"
          return 0
        fi
      else
        _log "Neither curl nor wget is installed"
        rm -f "$tmp"
        return 127
      fi
      i=$((i + 1))
      sleep 1
    done
  done

  rm -f "$tmp"
  _log "All download attempts failed"
  return 1
}

# github_url_chain ORIGIN_URL
# Prints: mirror ghproxy origin
github_url_chain() {
  origin="$1"
  base=${origin##*/}
  mirror="$MIRROR_BASE/$base"
  ghproxy="$GHPROXY_BASE$origin"
  printf '%s\n' "$mirror" "$ghproxy" "$origin"
}

