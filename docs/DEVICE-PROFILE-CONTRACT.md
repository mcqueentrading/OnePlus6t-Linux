# Device Profile Contract

Last updated: 2026-07-03

The builder is generic. The device profile is where phone-specific facts live.
This split matters because the OnePlus 6T needs Qualcomm firmware and SDM845
boot details that will not be identical on another phone.

## Required Profile Pieces

Each supported device profile should define:

```text
profiles/<device>/config.env
profiles/<device>/packages.txt
profiles/<device>/overlay/
vendor/<device>/boot/
docs/<device validation notes>
```

## Boot Stack

The profile must identify the working kernel/initramfs/DTB source and the boot
image parameters:

```text
kernel image
initramfs
extra initramfs or firmware ramdisk if required
device tree blob
root partition path or UUID
Android boot image header offsets
cmdline
```

For `oneplus-fajita`, this currently comes from the working postmarketOS SDM845
boot stack.

## Firmware

Firmware is not optional. The profile must list package firmware and any
device-specific firmware blobs needed for first boot graphics, Wi-Fi, Bluetooth,
modem, audio DSP, and sensors.

The OnePlus 6T first package-layer image missed Adreno firmware, which caused
Hyprland to crash until the A630 files were installed:

```text
/usr/lib/firmware/qcom/a630_sqe.fw
/usr/lib/firmware/qcom/a630_gmu.bin
/usr/lib/firmware/qcom/sdm845/oneplus6/a630_zap.mbn
```

The profile now includes:

```text
linux-firmware-qcom
```

For OnePlus 6T sensors, PMOS also requires the
`firmware-oneplus-sdm845-sensors` payload under
`/usr/share/qcom/sdm845/OnePlus/oneplus6`. The Arch profile must reproduce that
payload and the `fajita -> oneplus6` symlink before sensors can be considered
ported.

Do not treat live-copied firmware as enough for a release. If a device needs a
blob, the profile should either install it from a package or document a
repeatable extraction/staging step that the release builder can validate.

## Services

Profiles must enable the services needed for the hardware feature set, not just
install packages. For the OnePlus 6T this currently includes:

```text
sshd
NetworkManager
bluetooth
ModemManager
upower
pipewire
pipewire-pulse
wireplumber
hexagonrpcd-sdsp
hexagonrpcd-adsp-rootpd
hexagonrpcd-adsp-sensorspd
```

The `hexagonrpcd` units are dormant until `/usr/bin/hexagonrpcd` and the
matching `/dev/fastrpc-*` node exist. They are still part of the profile
contract because PMOS marks the inertial/light/proximity sensors as working
through that stack.

## Desktop And Controls

Profiles own the compositor policy that makes the phone usable:

```text
tty/autologin or display-manager startup
Hyprland include path
touch device output binding
power-key handling
volume-rocker handling
terminal and on-screen keyboard helpers
lock/wake policy
```

Hyprland options must be checked against the installed Hyprland build with:

```text
hyprctl descriptions
```

The OnePlus 6T currently runs Hyprland `0.55.4`, which accepts
`gestures:workspace_swipe_touch` and rejects older `workspace_swipe` enable and
finger-count keys.

## Validation

A profile is not complete until the feature map is tested on the target device:

```text
boot and SSH
display and GPU firmware
touchscreen
Wi-Fi association, DHCP, and DNS
Bluetooth scan/pairing
audio output, microphone, and volume rocker
battery and charging status
sensors
modem, SIM slot, SMS, and mobile data
USB OTG and dock behavior
suspend, wake, and power button behavior
```

Record evidence in `docs/STEP8-VALIDATION.md` or a device-specific validation
note before tagging a release image.
