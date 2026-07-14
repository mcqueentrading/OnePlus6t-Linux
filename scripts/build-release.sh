#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-oneplus-fajita}"

"$ROOT_DIR/scripts/build-bootimg.sh" "$PROFILE"
"$ROOT_DIR/scripts/build-rootfs-image.sh" "$PROFILE"

OUT_DIR="${OUT_DIR:-$ROOT_DIR/out/$PROFILE}"

echo
echo "Release artifacts:"
find "$OUT_DIR" -maxdepth 1 -type f \( -name '*.img' -o -name '*.sha256' \) -printf '%p\n' | sort
