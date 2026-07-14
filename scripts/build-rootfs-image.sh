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
CACHE_DIR="${CACHE_DIR:-$ROOT_DIR/cache}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/work/$PROFILE/rootfs}"
MNT_DIR="$WORK_DIR/mnt"
RAW_IMG="$OUT_DIR/oneplus6t-arch-root.raw.img"
SPARSE_IMG="$OUT_DIR/oneplus6t-arch-root.img"
ROOTFS_TARBALL="${ARCH_ROOTFS_TARBALL:-$CACHE_DIR/ArchLinuxARM-aarch64-latest.tar.gz}"
PACKAGE_MANIFEST="${PACKAGE_MANIFEST:-$PROFILE_DIR/packages.txt}"
INSTALL_PROFILE_PACKAGES="${INSTALL_PROFILE_PACKAGES:-1}"
PACMAN_CACHE_DIR="${PACMAN_CACHE_DIR:-$CACHE_DIR/alarm-packages/pkg}"
PACMAN_CONF="$WORK_DIR/pacman-aarch64.conf"
PACMAN_LOG="$WORK_DIR/pacman-rootfs.log"
PACMAN_HOOK_DIR="$WORK_DIR/empty-hooks"
PMOS_COMPAT_PAYLOAD_DIR="${PMOS_COMPAT_PAYLOAD_DIR:-}"
PMOS_HARDWARE_REFERENCE_TARBALL="${PMOS_HARDWARE_REFERENCE_TARBALL:-}"
LOCAL_PACKAGE_DIR="${LOCAL_PACKAGE_DIR:-$OUT_DIR/packages}"

if [[ "${ROOT_FSTYPE:-ext4}" != "ext4" ]]; then
  echo "Community Edition only builds ext4 root images. ROOT_FSTYPE=$ROOT_FSTYPE" >&2
  exit 1
fi

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This script must run as root because it creates and mounts a filesystem image." >&2
    echo "Use doas or sudo from the project root." >&2
    exit 1
  fi
}

require_tools() {
  local missing=0
  for tool in curl tar truncate mkfs.ext4 mount umount findmnt sha256sum rsync; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Missing required tool: $tool" >&2
      missing=1
    fi
  done
  if [[ "$INSTALL_PROFILE_PACKAGES" == "1" || -d "$LOCAL_PACKAGE_DIR" ]] && ! command -v pacman >/dev/null 2>&1; then
    echo "Missing required tool: pacman" >&2
    missing=1
  fi
  [[ "$missing" -eq 0 ]] || exit 1
}

download_rootfs() {
  mkdir -p "$CACHE_DIR"
  if [[ -f "$ROOTFS_TARBALL" ]]; then
    echo "Using cached/rootfs tarball: $ROOTFS_TARBALL"
    return
  fi
  echo "Downloading Arch Linux ARM rootfs:"
  echo "$ARCHLINUXARM_ROOTFS_URL"
  curl -L --fail --output "$ROOTFS_TARBALL" "$ARCHLINUXARM_ROOTFS_URL"
}

validate_pmos_boot_files() {
  local missing=0
  local file

  for file in "$PMOS_INITRAMFS" "$PMOS_INITRAMFS_EXTRA" "$PMOS_KERNEL" "$PMOS_DTB"; do
    if [[ ! -f "$PMOS_BOOT_DIR/$file" ]]; then
      echo "Missing PMOS boot artifact: $PMOS_BOOT_DIR/$file" >&2
      missing=1
    fi
  done

  if [[ "$missing" -ne 0 ]]; then
    cat >&2 <<EOF

Place the working PMOS boot artifacts in:
  $PMOS_BOOT_DIR

For local low-space builds, symlink that directory instead of copying it.
EOF
    exit 1
  fi
}

cleanup_mount() {
  if mountpoint -q "$MNT_DIR"; then
    umount "$MNT_DIR"
  fi
}

apply_overlay() {
  local overlay="$PROFILE_DIR/overlay"
  if [[ -d "$overlay" ]]; then
    rsync -a --no-owner --no-group "$overlay"/ "$MNT_DIR"/
  fi
}

install_pmos_compat_payload() {
  if [[ -z "$PMOS_COMPAT_PAYLOAD_DIR" || ! -d "$PMOS_COMPAT_PAYLOAD_DIR" ]]; then
    echo "No PMOS compatibility payload found; Wi-Fi/modem helper services will not be installed."
    return
  fi

  echo "Installing local PMOS compatibility payload:"
  echo "  $PMOS_COMPAT_PAYLOAD_DIR"
  rsync -a "$PMOS_COMPAT_PAYLOAD_DIR"/ "$MNT_DIR"/
}

install_pmos_hardware_reference() {
  local tmp

  if [[ -z "$PMOS_HARDWARE_REFERENCE_TARBALL" || ! -f "$PMOS_HARDWARE_REFERENCE_TARBALL" ]]; then
    echo "No PMOS hardware reference archive found; matching kernel modules/firmware will not be installed."
    return
  fi

  echo "Installing local PMOS hardware reference:"
  echo "  $PMOS_HARDWARE_REFERENCE_TARBALL"

  tmp="$(mktemp -d "$WORK_DIR/pmos-hw.XXXXXX")"
  tar -C "$tmp" -xf "$PMOS_HARDWARE_REFERENCE_TARBALL" \
    lib/modules/6.9.0-sdm845 \
    lib/firmware

  mkdir -p "$MNT_DIR/usr/lib/modules" "$MNT_DIR/usr/lib/firmware"
  rsync -a "$tmp/lib/modules"/ "$MNT_DIR/usr/lib/modules"/
  rsync -a "$tmp/lib/firmware"/ "$MNT_DIR/usr/lib/firmware"/
  chown -R 0:0 "$MNT_DIR/usr/lib/modules/6.9.0-sdm845" "$MNT_DIR/usr/lib/firmware"
}

enable_system_unit() {
  local unit="$1"
  local unit_path

  mkdir -p "$MNT_DIR/etc/systemd/system/multi-user.target.wants"

  for unit_path in \
    "$MNT_DIR/etc/systemd/system/$unit" \
    "$MNT_DIR/usr/lib/systemd/system/$unit"; do
    if [[ -f "$unit_path" ]]; then
      ln -sf "${unit_path#"$MNT_DIR"}" \
        "$MNT_DIR/etc/systemd/system/multi-user.target.wants/$unit"
      return
    fi
  done
}

enable_unit_for_target() {
  local unit="$1"
  local target="$2"
  local unit_path

  mkdir -p "$MNT_DIR/etc/systemd/system/$target.wants"

  for unit_path in \
    "$MNT_DIR/etc/systemd/system/$unit" \
    "$MNT_DIR/usr/lib/systemd/system/$unit"; do
    if [[ -f "$unit_path" ]]; then
      ln -sf "${unit_path#"$MNT_DIR"}" \
        "$MNT_DIR/etc/systemd/system/$target.wants/$unit"
      return
    fi
  done
}

fix_profile_ownership() {
  chown -h 0:0 "$MNT_DIR"
  chmod 0755 "$MNT_DIR"

  local root_path
  for root_path in bin boot dev etc lib lib64 mnt opt proc root run sbin srv sys tmp usr var; do
    if [[ -e "$MNT_DIR/$root_path" || -L "$MNT_DIR/$root_path" ]]; then
      chown -h 0:0 "$MNT_DIR/$root_path"
    fi
  done

  for root_path in boot etc opt root srv usr var; do
    if [[ -e "$MNT_DIR/$root_path" ]]; then
      chown -R 0:0 "$MNT_DIR/$root_path"
    fi
  done

  [[ -d "$MNT_DIR/tmp" ]] && chmod 1777 "$MNT_DIR/tmp"

  if [[ -d "$MNT_DIR/home/alarm" ]]; then
    chown -R 1000:1000 "$MNT_DIR/home/alarm"
  fi
  if [[ -d "$MNT_DIR/usr/local/bin" ]]; then
    chmod 0755 "$MNT_DIR/usr/local/bin"/oneplus6t-* 2>/dev/null || true
  fi
  for unit in \
    oneplus6t-uim-select.service \
    hexagonrpcd-sdsp.service \
    hexagonrpcd-adsp-rootpd.service \
    hexagonrpcd-adsp-sensorspd.service \
    pmos-compat-tqftpserv.service \
    pmos-compat-rmtfs.service \
    pmos-compat-pd-mapper.service; do
    enable_system_unit "$unit"
  done

  for unit in NetworkManager.service bluetooth.service ModemManager.service upower.service rtkit-daemon.service; do
    enable_system_unit "$unit"
  done

  enable_unit_for_target plymouth-start.service sysinit.target
  enable_unit_for_target plymouth-read-write.service sysinit.target
  enable_unit_for_target plymouth-quit.service multi-user.target
  enable_unit_for_target plymouth-quit-wait.service multi-user.target

  mkdir -p "$MNT_DIR/etc/systemd/user/default.target.wants" \
    "$MNT_DIR/etc/systemd/user/sockets.target.wants" \
    "$MNT_DIR/etc/systemd/user/pipewire.service.wants"

  for unit in pipewire.service pipewire-pulse.service; do
    if [[ -f "$MNT_DIR/usr/lib/systemd/user/$unit" ]]; then
      ln -sf "/usr/lib/systemd/user/$unit" \
        "$MNT_DIR/etc/systemd/user/default.target.wants/$unit"
    fi
  done

  for socket in pipewire.socket pipewire-pulse.socket; do
    if [[ -f "$MNT_DIR/usr/lib/systemd/user/$socket" ]]; then
      ln -sf "/usr/lib/systemd/user/$socket" \
        "$MNT_DIR/etc/systemd/user/sockets.target.wants/$socket"
    fi
  done

  if [[ -f "$MNT_DIR/usr/lib/systemd/user/wireplumber.service" ]]; then
    ln -sf /usr/lib/systemd/user/wireplumber.service \
      "$MNT_DIR/etc/systemd/user/default.target.wants/wireplumber.service"
    ln -sf /usr/lib/systemd/user/wireplumber.service \
      "$MNT_DIR/etc/systemd/user/pipewire.service.wants/wireplumber.service"
    ln -sf /usr/lib/systemd/user/wireplumber.service \
      "$MNT_DIR/etc/systemd/user/pipewire-session-manager.service"
  fi
}

enable_insecure_password_if_requested() {
  if [[ "$ALLOW_INSECURE_DEFAULT_PASSWORD" != "1" ]]; then
    return
  fi

  echo "WARNING: enabling insecure local test password root/alarm"
  local hash
  hash="$(openssl passwd -6 alarm)"
  awk -F: -v "hash=$hash" 'BEGIN { OFS = ":" } $1 == "root" { $2 = hash } { print }' \
    "$MNT_DIR/etc/shadow" > "$MNT_DIR/etc/shadow.new"
  mv "$MNT_DIR/etc/shadow.new" "$MNT_DIR/etc/shadow"
  chmod 000 "$MNT_DIR/etc/shadow"

  mkdir -p "$MNT_DIR/etc/ssh/sshd_config.d"
  cat > "$MNT_DIR/etc/ssh/sshd_config.d/90-linuxphone-dev.conf" <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
EOF
}

install_pmos_boot_files() {
  mkdir -p "$MNT_DIR/boot/pmos-current"
  cp -a "$PMOS_BOOT_DIR/$PMOS_INITRAMFS" "$MNT_DIR/boot/initramfs"
  cp -a "$PMOS_BOOT_DIR/$PMOS_INITRAMFS_EXTRA" "$MNT_DIR/boot/initramfs-extra"
  cp -a "$PMOS_BOOT_DIR/$PMOS_KERNEL" "$MNT_DIR/boot/vmlinuz"
  cp -a "$PMOS_BOOT_DIR/$PMOS_DTB" "$MNT_DIR/boot/sdm845-oneplus-fajita.dtb"
  [[ -f "$PMOS_BOOT_DIR/linux.efi" ]] && cp -a "$PMOS_BOOT_DIR/linux.efi" "$MNT_DIR/boot/linux.efi"
  cp -a "$PMOS_BOOT_DIR"/. "$MNT_DIR/boot/pmos-current/"
}

read_package_manifest() {
  if [[ ! -f "$PACKAGE_MANIFEST" ]]; then
    echo "Missing package manifest: $PACKAGE_MANIFEST" >&2
    exit 1
  fi

  mapfile -t PROFILE_PACKAGES < <(awk '
    /^[[:space:]]*($|#)/ { next }
    { print $1 }
  ' "$PACKAGE_MANIFEST")
}

write_alarm_pacman_conf() {
  mkdir -p "$PACMAN_CACHE_DIR" "$PACMAN_HOOK_DIR"
  cat > "$PACMAN_CONF" <<'EOF'
[options]
Architecture = aarch64
SigLevel = Never
LocalFileSigLevel = Never
ParallelDownloads = 5
DisableSandbox

[core]
Server = http://mirror.archlinuxarm.org/$arch/$repo

[extra]
Server = http://mirror.archlinuxarm.org/$arch/$repo

[alarm]
Server = http://mirror.archlinuxarm.org/$arch/$repo

[aur]
Server = http://mirror.archlinuxarm.org/$arch/$repo
EOF
}

install_profile_packages() {
  if [[ "$INSTALL_PROFILE_PACKAGES" != "1" ]]; then
    echo "Skipping profile package installation because INSTALL_PROFILE_PACKAGES=$INSTALL_PROFILE_PACKAGES"
    return
  fi

  read_package_manifest
  if [[ "${#PROFILE_PACKAGES[@]}" -eq 0 ]]; then
    echo "Package manifest is empty: $PACKAGE_MANIFEST"
    return
  fi

  write_alarm_pacman_conf
  echo "Installing ${#PROFILE_PACKAGES[@]} profile packages into root image:"
  printf '  %s\n' "${PROFILE_PACKAGES[@]}"

  pacman \
    --root "$MNT_DIR" \
    --config "$PACMAN_CONF" \
    --cachedir "$PACMAN_CACHE_DIR" \
    --logfile "$PACMAN_LOG" \
    --hookdir "$PACMAN_HOOK_DIR" \
    --arch aarch64 \
    --noconfirm \
    --needed \
    --noscriptlet \
    -Sy "${PROFILE_PACKAGES[@]}"
}

install_local_packages() {
  local packages=()
  local package

  if [[ ! -d "$LOCAL_PACKAGE_DIR" ]]; then
    echo "No local package directory found; skipping local package injection."
    echo "  $LOCAL_PACKAGE_DIR"
    return
  fi

  while IFS= read -r -d '' package; do
    packages+=("$package")
  done < <(find "$LOCAL_PACKAGE_DIR" -maxdepth 1 -type f \
    \( -name '*.pkg.tar.zst' -o -name '*.pkg.tar.xz' -o -name '*.pkg.tar.gz' \) \
    -print0 | sort -z)

  if [[ "${#packages[@]}" -eq 0 ]]; then
    echo "No local packages found; skipping local package injection."
    echo "  $LOCAL_PACKAGE_DIR"
    return
  fi

  write_alarm_pacman_conf
  echo "Installing ${#packages[@]} local package(s) into root image:"
  printf '  %s\n' "${packages[@]}"

  pacman \
    --root "$MNT_DIR" \
    --config "$PACMAN_CONF" \
    --cachedir "$PACMAN_CACHE_DIR" \
    --logfile "$PACMAN_LOG" \
    --hookdir "$PACMAN_HOOK_DIR" \
    --arch aarch64 \
    --noconfirm \
    --needed \
    --noscriptlet \
    -U "${packages[@]}"
}

write_pacman_runtime_config() {
  local conf="$MNT_DIR/etc/pacman.conf"

  if [[ ! -f "$conf" ]]; then
    return
  fi

  if ! grep -Eq '^[[:space:]]*DisableSandbox([[:space:]]|$)' "$conf"; then
    sed -i '/^\[options\]/a DisableSandbox' "$conf"
  fi
}

main() {
  need_root
  require_tools
  validate_pmos_boot_files
  download_rootfs

  rm -rf "$WORK_DIR"
  mkdir -p "$OUT_DIR" "$WORK_DIR" "$MNT_DIR"
  trap cleanup_mount EXIT

  rm -f "$RAW_IMG" "$SPARSE_IMG" "$RAW_IMG.sha256" "$SPARSE_IMG.sha256"
  truncate -s "$ROOT_IMAGE_SIZE" "$RAW_IMG"
  mkfs.ext4 -F -L "$ROOT_LABEL" -U "$ROOT_UUID" "$RAW_IMG"
  mount -o loop,rw,noatime "$RAW_IMG" "$MNT_DIR"

  tar -xpf "$ROOTFS_TARBALL" -C "$MNT_DIR"
  install_profile_packages
  install_local_packages
  write_pacman_runtime_config
  install_pmos_boot_files

cat > "$MNT_DIR/etc/fstab" <<EOF
# linuxphone Arch root on ${ROOT_DEVICE}
UUID=${ROOT_UUID} / ${ROOT_FSTYPE} rw,noatime 0 1
EOF

  mkdir -p "$MNT_DIR/etc/systemd/system/multi-user.target.wants"
  ln -sf /usr/lib/systemd/system/sshd.service \
    "$MNT_DIR/etc/systemd/system/multi-user.target.wants/sshd.service"

  apply_overlay
  install_pmos_hardware_reference
  install_pmos_compat_payload
  fix_profile_ownership
  enable_insecure_password_if_requested

  sync
  umount "$MNT_DIR"
  trap - EXIT

  if command -v img2simg >/dev/null 2>&1; then
    img2simg "$RAW_IMG" "$SPARSE_IMG"
    sha256sum "$SPARSE_IMG" > "$SPARSE_IMG.sha256"
    echo "Built Android sparse root image:"
    echo "$SPARSE_IMG"
    cat "$SPARSE_IMG.sha256"
  else
    sha256sum "$RAW_IMG" > "$RAW_IMG.sha256"
    echo "img2simg not found; built raw root image only:"
    echo "$RAW_IMG"
    cat "$RAW_IMG.sha256"
  fi
}

main "$@"
