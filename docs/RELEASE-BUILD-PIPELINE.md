# Release Build Pipeline

Goal: make this project reproducible enough that a Linux user can build or download
two files and flash a OnePlus 6T:

```text
oneplus6t-arch-boot.img
oneplus6t-arch-root.img
```

Target flash shape:

```text
fastboot flash boot oneplus6t-arch-boot.img
fastboot flash userdata oneplus6t-arch-root.img
```

The scripted local flash path is:

```text
CONFIRM_FLASH=1 scripts/flash-release.sh oneplus-fajita
```

Do not flash only `userdata` when testing a new root UUID, partition target, or
PMOS stowaway cmdline. The boot image owns the initramfs root handoff.

## Repository Shape

Keep source in git:

```text
profiles/oneplus-fajita/config.env
profiles/oneplus-fajita/overlay/
scripts/build-bootimg.sh
scripts/build-rootfs-image.sh
scripts/build-release.sh
scripts/flash-release.sh
docs/
```

Keep generated artifacts out of git:

```text
out/
cache/
work/
*.img
*.tar.zst
```

Publish generated images through GitHub Releases or another artifact store, not
normal git history.

## Builder Layers

1. `build-rootfs-image.sh`

   Downloads or uses an Arch Linux ARM aarch64 rootfs tarball, creates an ext4
   userdata image, installs `profiles/oneplus-fajita/packages.txt`, injects PMOS
   boot artifacts, writes `fstab`, applies the OnePlus 6T overlay, and converts
   the raw image to Android sparse format when `img2simg` is available.

2. `build-bootimg.sh`

   Concatenates the PMOS `vmlinuz` and `sdm845-oneplus-fajita.dtb`, then creates
   an Android `boot.img` using the known-good OnePlus 6T mkbootimg offsets.

3. `build-release.sh`

   Runs both builders and writes checksums for the release files.

4. `flash-release.sh`

   Verifies SHA-256 files, then flashes boot and userdata as a pair. It refuses
   to run unless `CONFIRM_FLASH=1` is set, because it replaces userdata.
   Community Edition uses `FASTBOOT_SPARSE_SIZE=0` by default, so it does not
   force the smaller sparse chunks used by more conservative lab builds.

## Quiet Boot

The profile command line uses `quiet splash loglevel=3`,
`rd.udev.log_level=3`, `systemd.show_status=false`, and
`vt.global_cursor_default=0`. The root image installs Plymouth and enables the
standard Plymouth systemd units when the package provides them.

This is a userspace Plymouth path. Very early messages from the imported PMOS
kernel/initramfs may still appear until the boot artifacts themselves are
rebuilt with a Plymouth-aware initramfs.

## Current Known-Good Boot Rule

The current layout is plain ext4 on `/dev/sda17`, not the old PMOS userdata
subpartition layout. The boot image must use:

```text
pmos.stowaway
pmos_root_uuid=8f3b0c30-9845-451d-aed4-7e80541a0d29
pmos_root=/dev/sda17
rootfstype=ext4
```

Do not include:

```text
pmos_boot_uuid=b5e4e3d4-455d-4352-904d-a84f4427c85a
```

That UUID belonged to the erased PMOS boot subpartition.

The Community Edition root image is fixed at 8GB and formatted as ext4.

## Open Work Before Public Release

- Prove the latest generated paired boot/root release after flash. Latest
  flashed root image:
  `c2d5480919556b45c9283810941d3f92c645dea9e7cde9875889b866a8af9ab8`.
- Replace the insecure local test password with SSH-key-only onboarding.
- Prove the package manifest install against a fresh generated root image.
- Integrate the Qualcomm helper services needed for Wi-Fi/modem bring-up:
  `tqftpserv`, `rmtfs -P -s`, and `pd-mapper`.
- Add a hardware test report: display, touch, GPU, Wi-Fi, Bluetooth, audio,
  suspend, charging, USB networking, USB-C dock/display, sensors.
- Add release signing, checksums, and a rollback/recovery doc.
