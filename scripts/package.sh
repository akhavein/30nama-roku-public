#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
mkdir -p "$ROOT/build"
PACKAGE=$(mktemp "$ROOT/build/channel.XXXXXX")
# zip expects a new archive path, so use its .zip sibling.
(cd "$ROOT" && zip -qr "$PACKAGE.zip" manifest source components images)
unzip -t "$PACKAGE.zip" >/dev/null
mv "$PACKAGE.zip" "$ROOT/build/30nama-roku.zip"
unlink "$PACKAGE"
echo "$ROOT/build/30nama-roku.zip"
