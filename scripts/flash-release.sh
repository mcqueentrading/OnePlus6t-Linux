#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: CONFIRM_FLASH=1 $0 [profile]

Flashes the paired release artifacts:
  fastboot flash boot     out/<profile>/oneplus6t-arch-boot.img
  fastboot flash userdata out/<profile>/oneplus6t-arch-root.img

This erases/replaces userdata. Set REBOOT_AFTER_FLASH=0 to skip fastboot reboot.
The default userdata transfer uses FASTBOOT_SPARSE_SIZE=0, meaning no forced
small sparse chunks.
EOF
  exit 0
fi

PROFILE="${1:-oneplus-fajita}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/out/$PROFILE}"
BOOT_IMG="$OUT_DIR/oneplus6t-arch-boot.img"
ROOT_IMG="$OUT_DIR/oneplus6t-arch-root.img"
BOOT_SUM="$BOOT_IMG.sha256"
ROOT_SUM="$ROOT_IMG.sha256"
REBOOT_AFTER_FLASH="${REBOOT_AFTER_FLASH:-1}"
FASTBOOT_SPARSE_SIZE="${FASTBOOT_SPARSE_SIZE:-0}"

usage() {
  cat <<EOF
Usage: CONFIRM_FLASH=1 $0 [profile]

Flashes the paired release artifacts:
  fastboot flash boot     $BOOT_IMG
  fastboot flash userdata $ROOT_IMG

This erases/replaces userdata. Set REBOOT_AFTER_FLASH=0 to skip fastboot reboot.
The default userdata transfer uses FASTBOOT_SPARSE_SIZE=0, meaning no forced
small sparse chunks.
EOF
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required artifact: $path" >&2
    exit 1
  fi
}

for tool in fastboot sha256sum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

require_file "$BOOT_IMG"
require_file "$ROOT_IMG"
require_file "$BOOT_SUM"
require_file "$ROOT_SUM"

sha256sum -c "$BOOT_SUM"
sha256sum -c "$ROOT_SUM"

if ! fastboot devices | awk 'NF >= 2 && $2 == "fastboot" { found = 1 } END { exit !found }'; then
  echo "No fastboot device detected." >&2
  exit 1
fi

if [[ "${CONFIRM_FLASH:-0}" != "1" ]]; then
  usage >&2
  echo >&2
  echo "Refusing to flash without CONFIRM_FLASH=1." >&2
  exit 1
fi

echo "Flashing paired OnePlus 6T Arch release artifacts:"
echo "  boot:     $BOOT_IMG"
echo "  userdata: $ROOT_IMG"
echo "  userdata sparse chunk size: $FASTBOOT_SPARSE_SIZE"

fastboot flash boot "$BOOT_IMG"
fastboot -S "$FASTBOOT_SPARSE_SIZE" flash userdata "$ROOT_IMG"

if [[ "$REBOOT_AFTER_FLASH" == "1" ]]; then
  fastboot reboot
else
  echo "Skipping reboot because REBOOT_AFTER_FLASH=$REBOOT_AFTER_FLASH"
fi
