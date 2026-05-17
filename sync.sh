#!/bin/sh
# Sync from upstream and re-deploy.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

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

cd "$DIR"

if [ ! -d sing-box/.git ]; then
  echo "Cloning upstream repo..." >&2
  git clone https://github.com/fscarmen/sing-box.git sing-box || \
    git clone "https://ghproxy.com/https://github.com/fscarmen/sing-box.git" sing-box
fi

cd "$DIR/sing-box"
if ! git remote | grep -qx upstream; then
  git remote add upstream https://github.com/fscarmen/sing-box.git
fi

echo "Fetching upstream..."
git fetch upstream

echo "Merging upstream/main..."
git checkout main >/dev/null 2>&1 || true
git merge --ff-only upstream/main || {
  echo "Non fast-forward merge required; resolve manually" >&2
  exit 1
}

cd "$DIR"

echo "Repack + deploy..."
"$DIR/deploy.sh"

