# Qualcomm Services For Wi-Fi And Modem Bring-Up

Last updated: 2026-07-03 01:29 BST

The OnePlus 6T Arch prototype needs more than firmware blobs for Wi-Fi and
cellular-adjacent hardware. On SDM845, the modem/Wi-Fi remoteproc path also
depends on Qualcomm userspace helpers normally started by postmarketOS.

## Observed Failure

The Arch root booted from `/dev/sda17`, but Wi-Fi did not appear.

Initial state:

```text
ath10k_snoc: module loaded
NetworkManager: active
wlan0: absent
ip link: lo, usb0 only
```

The driver stopped after:

```text
ath10k_snoc 18800000.wifi: Adding to iommu group 10
```

## Required Services

The working PMOS service set is:

```text
tqftpserv
rmtfs -P -s
pd-mapper
```

For mobile data, the system will also need a real cellular userspace stack, most
likely:

```text
ModemManager
libqmi/qmicli
mobile broadband provider/APN data
```

## Prototype Fix

The live prototype temporarily runs PMOS-compatible builds of:

```text
/opt/pmos-compat/bin/tqftpserv
/opt/pmos-compat/bin/pd-mapper
/opt/pmos-compat/sbin/rmtfs
```

These are supervised by:

```text
pmos-compat-tqftpserv.service
pmos-compat-rmtfs.service
pmos-compat-pd-mapper.service
```

The PMOS helper binaries used on the prototype are Alpine/musl aarch64 binaries.
The prototype keeps their libraries under `/opt/pmos-compat/lib` and selects
them with `LD_LIBRARY_PATH` in the unit files. Only the musl loader is placed at
`/usr/lib/ld-musl-aarch64.so.1`, because the binary interpreter path is
`/lib/ld-musl-aarch64.so.1` and Arch has `/lib -> usr/lib`.

Do not copy a PMOS `/lib` directory onto Arch. That can replace Arch's `/lib`
symlink and break the root filesystem.

## Verified Result

After starting the three services, the modem remoteproc powered up:

```text
remoteproc remoteproc0: powering up 4080000.remoteproc
remoteproc remoteproc0: remote processor 4080000.remoteproc is now up
ipa 1e40000.ipa: received modem running event
```

Wi-Fi then completed initialization:

```text
ath10k_snoc 18800000.wifi: qmi chip_id 0x30214 chip_family 0x4001
ath10k_snoc 18800000.wifi: wcn3990 hw1.0 target 0x00000008
ath10k_snoc 18800000.wifi: firmware ver api 5
```

NetworkManager result:

```text
wlan0: present
p2p-dev-wlan0: present
scan-only test: passed
```

## Cellular Status

Low-level modem state after the same service bring-up:

```text
rmnet_ipa0: present
modem remoteproc: running
```

Not yet validated:

```text
SIM detection
APN setup
mobile data attach
ModemManager/libqmi integration
```

No SIM was inserted during this validation pass.

## Release Requirement

This repository should not commit opaque PMOS binary payloads. Before a public
release, the builder needs one of these clean paths:

```text
native Arch packages for tqftpserv/rmtfs/pd-mapper
or
documented redistributable PMOS/Alpine package extraction with checksums/licenses
```

The generated root image should then:

1. install the required firmware under `/usr/lib/firmware`;
2. install or build `tqftpserv`, `rmtfs`, and `pd-mapper`;
3. enable the three systemd services;
4. prove Wi-Fi survives reboot;
5. add and validate the cellular stack with a real SIM.
