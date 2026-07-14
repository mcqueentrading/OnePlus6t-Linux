#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-oneplus-fajita}"
PROFILE_DIR="$ROOT_DIR/profiles/$PROFILE"

if [[ ! -f "$PROFILE_DIR/config.env" ]]; then
  echo "Missing profile config: $PROFILE_DIR/config.env" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$PROFILE_DIR/config.env"

OUT_DIR="${OUT_DIR:-$ROOT_DIR/out/$PROFILE}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/work/$PROFILE/bootimg}"
mkdir -p "$OUT_DIR" "$WORK_DIR"

for tool in mkbootimg sha256sum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

kernel_path="$PMOS_BOOT_DIR/$PMOS_KERNEL"
dtb_path="$PMOS_BOOT_DIR/$PMOS_DTB"
ramdisk_path="$PMOS_BOOT_DIR/$PMOS_INITRAMFS"

for path in "$kernel_path" "$dtb_path" "$ramdisk_path"; do
  if [[ ! -f "$path" ]]; then
    echo "Missing PMOS boot artifact: $path" >&2
    exit 1
  fi
done

kernel_dtb="$WORK_DIR/kernel-dtb"
boot_img="$OUT_DIR/oneplus6t-arch-boot.img"

cat "$kernel_path" "$dtb_path" > "$kernel_dtb"

mkbootimg \
  --kernel "$kernel_dtb" \
  --ramdisk "$ramdisk_path" \
  --cmdline "$BOOT_CMDLINE" \
  --base "$BOOT_BASE" \
  --kernel_offset "$BOOT_KERNEL_OFFSET" \
  --ramdisk_offset "$BOOT_RAMDISK_OFFSET" \
  --second_offset "$BOOT_SECOND_OFFSET" \
  --tags_offset "$BOOT_TAGS_OFFSET" \
  --pagesize "$BOOT_PAGESIZE" \
  --header_version "$BOOT_HEADER_VERSION" \
  -o "$boot_img"

sha256sum "$boot_img" > "$boot_img.sha256"

echo "Built boot image:"
echo "$boot_img"
cat "$boot_img.sha256"
