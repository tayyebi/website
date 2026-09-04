#!/bin/sh
# Bring the site up, fetching the serve-md binary first if it is not here yet.
#
# The binary is not committed (see .gitignore): it is a ~1.3M platform-specific
# build that belongs to https://github.com/tayyebi/serve-md, not to this mirror.
set -eu

REPO=tayyebi/serve-md
BIN=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/serve-md

# Always a Linux build: the binary is mounted into the Alpine container by
# compose.yaml, never executed on the host. Only the architecture varies, and
# it follows the host because Docker runs containers natively.
arch=$(uname -m)
case "$arch" in
    aarch64 | arm64) asset=serve-md-linux-aarch64 ;;
    x86_64 | amd64)  asset=serve-md-linux-x86_64 ;;
    *)
        echo "entrypoint: no serve-md release build for $arch" >&2
        exit 1
        ;;
esac

if [ ! -x "$BIN" ]; then
    url="https://github.com/$REPO/releases/latest/download/$asset"
    echo "entrypoint: serve-md missing, downloading $asset..." >&2

    # Download beside the target and move into place, so an interrupted or
    # failed transfer never leaves a half-written binary that looks installed.
    tmp="$BIN.download.$$"
    trap 'rm -f "$tmp"' EXIT
    # --fail so an HTML error page is not saved as the binary, --location to
    # follow the /latest/download redirect to the actual asset.
    curl --fail --location --progress-bar --output "$tmp" "$url"
    chmod +x "$tmp"
    mv "$tmp" "$BIN"
    trap - EXIT

    echo "entrypoint: installed $BIN" >&2
fi

# Any extra arguments are passed to compose, so `./entrypoint.sh -d` detaches.
exec docker compose up "$@"
