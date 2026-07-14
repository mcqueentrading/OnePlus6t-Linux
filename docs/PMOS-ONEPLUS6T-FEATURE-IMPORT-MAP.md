# PMOS OnePlus 6T Feature Import Map

Last updated: 2026-07-03 18:55 BST

This project uses the postmarketOS OnePlus 6T page and official pmaports device
package as the hardware reference for what is realistic on `oneplus-fajita`.

The observed PMOS page identifies:

```text
device package: device-oneplus-fajita
kernel package: linux-postmarketos-qcom-sdm845
SoC family: Snapdragon 845
family reference: device-oneplus-enchilada
```

## Rule

Use PMOS as the working reference implementation, but do not copy whole PMOS
directories into Arch.

Good import targets:

```text
firmware
small config files
service behavior translated into systemd units
helper daemons packaged or rebuilt for Arch
documented checksums and source packages
```

Bad import targets:

```text
PMOS /lib copied over Arch
PMOS /usr copied wholesale
opaque local binary payloads committed into git
```

## Feature Matrix

| Area | Feature | PMOS status | Arch prototype status | Import target |
| --- | --- | --- | --- | --- |
| Flashing | Flashing | Works | Works locally | Fastboot boot/root release path |
| Flashing | USB Networking | Works | Works | PMOS USB gadget/initramfs behavior |
| Flashing | Battery | Works | Working through UPower | Battery/charger kernel + UPower rules |
| Flashing | Screen | Works | Works | PMOS kernel, DTB, display stack |
| Flashing | Touchscreen | Works | Needs gesture validation | Kernel/DTB/input quirks |
| Multimedia | 3D Acceleration | Works | DRI nodes present | Kernel/firmware + Mesa/Adreno userspace |
| Multimedia | Audio | Partial | Pro Audio sinks/sources visible | ALSA UCM, PipeWire/WirePlumber routing |
| Connectivity | Wi-Fi | Works | Scan-only works | WCN3990 firmware + Qualcomm helper services |
| Connectivity | Bluetooth | Works | hci0 present, BlueZ Invalid Index | BT firmware and BlueZ setup |
| Connectivity | GPS | Partial | Not validated | GNSS/modem location stack |
| Connectivity | NFC | Partial | Not validated | NFC kernel/userspace stack |
| Modem | Calls | Partial | Not validated | ModemManager/oFono/call audio routing |
| Modem | SMS | Works | Modem registered, SMS not tested | ModemManager/libqmi/SIM setup |
| Modem | Mobile data | Works | LTE/PS attach works; PDP attach crashes ModemManager | Modem services + ModemManager/libqmi/APN |
| Misc | FDE | Works | Deferred | Add after installer is stable |
| Misc | USB OTG | Partial | Not validated | USB role-switch/Type-C/power rules |
| Sensors | Accelerometer / gyro backend | Works | Missing from SensorProxy; Hyprland fixed portrait | `hexagonrpcd`, sensor firmware, libssc mount matrix, iio-sensor-proxy |
| Sensors | Magnetometer | Works | Missing from SensorProxy | `hexagonrpcd`, sensor firmware, libssc mount matrix, iio-sensor-proxy |
| Sensors | Ambient Light | Works | Missing from SensorProxy | `hexagonrpcd`, sensor firmware, libssc mount matrix, iio-sensor-proxy |
| Sensors | Proximity | Works | Missing from SensorProxy | `hexagonrpcd`, sensor firmware, libssc mount matrix, iio-sensor-proxy |
| Sensors | Hall Effect | Broken | Not expected initially | Deprioritize |
| Sensors | Haptics | Works | Input node visible | Haptics kernel and permission rules |
| Sensors | Barometer | Broken | Not expected initially | Deprioritize |

## Priority

1. Validate Wi-Fi association and persistence with real credentials.
2. Fix BlueZ controller management index, then validate pairing.
3. Fix ModemManager qmapmux/PDP attach crash, then validate SMS/mobile data.
4. Validate speaker/mic through the Pro Audio profile.
5. Package `hexagonrpcd` from `linux-msm/hexagonrpc`, install the
   `firmware-oneplus-sdm845-sensors` payload, then validate
   accelerometer/proximity backend. Community Edition intentionally does not
   ship a custom compositor rotation plugin.
6. Test USB OTG/dock behavior; current typec/usb_role classes are empty.
7. Keep advanced multimedia capture out of Community Edition; treat it as a
   separate downstream/supporter research track.

## OnePlus 6 Family Import Notes

Detailed pmaports source findings are saved in:

```text
docs/PMOS-ONEPLUS6-FAMILY-REFERENCE.md
```

Use `oneplus-enchilada` as a family reference only. The public 6T profile must
keep the `oneplus-fajita` DTB, 1080x2340 display geometry, and 6T-specific
libssc mount matrix.
