# PMOS "Works" Feature Checklist

Last updated: 2026-07-03

This checklist tracks the postmarketOS features marked `Works` for the OnePlus
6T and the current Arch prototype status.

## Confirmed Or Partly Ported To Arch

| PMOS feature | Arch status | Method in this repo |
| --- | --- | --- |
| Flashing | Working locally | `scripts/build-bootimg.sh`, boot/root release layout docs |
| USB Networking | Working | PMOS initramfs/gadget path; host uses `172.16.42.2/24`, phone `172.16.42.1` |
| Battery | Kernel-visible | `/sys/class/power_supply` works; release package list includes `upower` |
| Screen | Working | PMOS SDM845 kernel/DTB plus stock-style Hyprland config |
| Touchscreen | Device visible | Synaptics input device exposed to userspace |
| 3D Acceleration | DRI nodes present, needs render benchmark | PMOS kernel/firmware; release still needs GPU smoke test |
| Wi-Fi | Scan-only works | WCN3990 firmware plus `tqftpserv`, `rmtfs`, `pd-mapper`, `ath10k_snoc` |
| Mobile data | SIM/UIM, LTE registration, and PS attach work; PDP start crashes ModemManager | Native ModemManager/libqmi sees `qrtr0` and `rmnet_ipa0`; qmapmux activation needs fixing |
| Haptics | Input node visible | `spmi_haptics` exists; needs userspace test |
| Audio | Pro Audio sinks/sources visible | `pactl set-card-profile alsa_card.platform-sound pro-audio`; playback/mic still need physical test |
| Battery | Working through UPower | `upower -d` reports charging, percentage, time-to-full, and temperature |

## Needs Userspace Packages Or Physical Validation

| PMOS feature | Current blocker | Planned package/config |
| --- | --- | --- |
| Bluetooth | Firmware boots `hci0`, but BlueZ has no valid management index | Investigate `btqcomsmd`/`hci_uart` path and kernel BlueZ management registration |
| SMS | Modem is registered but SMS not tested | Validate with ModemManager after data-attach crash is fixed |
| Accelerometer / gyro backend | `iio-sensor-proxy` runs but reports no accelerometer; Hyprland stays fixed portrait | Package `hexagonrpcd`, install OnePlus SDM845 sensor firmware, keep 6T libssc matrix; no custom compositor rotation plugin in Community Edition |
| Magnetometer | `iio-sensor-proxy` runs but reports no compass | Package `hexagonrpcd`, install OnePlus SDM845 sensor firmware, keep 6T libssc matrix |
| Ambient Light | `iio-sensor-proxy` runs but reports no light sensor | Package `hexagonrpcd`, install OnePlus SDM845 sensor firmware, keep 6T libssc matrix |
| Proximity | `iio-sensor-proxy` runs but reports no proximity sensor | Package `hexagonrpcd`, install OnePlus SDM845 sensor firmware, keep 6T libssc matrix |
| FDE | Not part of the current prototype | Defer until installer is stable |

## Still Partial In PMOS Too

These should be handled after the `Works` list is solid:

```text
Audio
GPS
NFC
Calls
USB OTG
```

## Upstream Family Reference

The OnePlus 6 PMOS package confirms the shared SDM845 stack, but `fajita` keeps
its own DTB, screen height, and sensor mount matrix. Details are saved in:

```text
docs/PMOS-ONEPLUS6-FAMILY-REFERENCE.md
```
