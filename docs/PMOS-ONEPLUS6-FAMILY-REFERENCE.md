# PMOS OnePlus 6 Family Reference

Last updated: 2026-07-03

This note records what we imported from the official postmarketOS OnePlus 6
family packages. The OnePlus 6 (`oneplus-enchilada`) is useful because it shares
the SDM845 family stack with the OnePlus 6T (`oneplus-fajita`), but the release
profile must keep the 6T-specific display height, DTB, and sensor mount matrix.

## Upstream Sources

Official postmarketOS pmaports sources checked:

```text
https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/community/device-oneplus-fajita/APKBUILD
https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/community/device-oneplus-fajita/deviceinfo
https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/community/device-oneplus-fajita/hexagonrpcd.confd
https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/community/device-oneplus-fajita/81-libssc-oneplus-fajita.rules
https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/community/device-oneplus-fajita/q6voiced.conf
https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/community/device-oneplus-enchilada/APKBUILD
https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/community/device-oneplus-enchilada/deviceinfo
https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/master/device/community/firmware-oneplus-sdm845/APKBUILD
```

Official Alpine package source checked:

```text
https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/hexagonrpcd/APKBUILD
https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/hexagonrpcd/systemd-services.patch
https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/hexagonrpcd/10-fastrpc.rules
https://github.com/linux-msm/hexagonrpc
```

## Device Package Facts

Both OnePlus 6 and OnePlus 6T depend on the same core stack:

```text
alsa-ucm-conf-sdm845
firmware-oneplus-sdm845>=9
firmware-oneplus-sdm845-sensors
hexagonrpcd>=0.3.2-r3
linux-postmarketos-qcom-sdm845
soc-qcom
soc-qcom-modem
soc-qcom-qbootctl
unl0kr-fbforcerefresh
```

For Arch, the important point is that PMOS sensor support is not only
`iio-sensor-proxy`. It requires:

```text
fastrpc kernel device nodes
hexagonrpcd user/group and daemon
firmware-oneplus-sdm845-sensors files
/usr/share/hexagonrpcd/hexagonrpcd-sdsp.conf
the libssc mount-matrix udev rule
```

## Boot Parameters

`oneplus-fajita` and `oneplus-enchilada` use the same Android boot image
offsets:

```text
base: 0x00000000
kernel: 0x00008000
ramdisk: 0x01000000
second: 0x00f00000
tags: 0x00000100
pagesize: 4096
sparse root image: true
rootfs image sector size: 4096
append DTB: true
```

Keep the 6T-specific values:

```text
codename: oneplus-fajita
screen: 1080x2340
DTB: qcom/sdm845-oneplus-fajita
```

The OnePlus 6 differs here:

```text
codename: oneplus-enchilada
screen: 1080x2280
DTB: qcom/sdm845-oneplus-enchilada
```

## Sensor Stack Import

The 6T-specific files now mirrored in the Arch profile are:

```text
profiles/oneplus-fajita/overlay/usr/share/hexagonrpcd/hexagonrpcd-sdsp.conf
profiles/oneplus-fajita/overlay/usr/lib/udev/rules.d/81-libssc-oneplus-fajita.rules
profiles/oneplus-fajita/overlay/etc/conf.d/q6voiced
```

The 6T mount matrix must stay:

```text
-1, 0, 0; 0, 1, 0; 0, 0, -1
```

Do not replace it with the OnePlus 6 matrix. The OnePlus 6 package uses the
same firmware directory and voice config, but not the same physical screen
height or DTB.

## Hexagonrpcd Packaging Task

Alpine edge packages `hexagonrpcd` from `https://github.com/linux-msm/hexagonrpc`
as version `0.4.0-r3` in `community/aarch64`.

The Arch release needs a package or local build step that installs:

```text
/usr/bin/hexagonrpcd
/usr/lib/udev/rules.d/10-fastrpc.rules
/usr/lib/systemd/system/hexagonrpcd-sdsp.service
/usr/lib/systemd/system/hexagonrpcd-adsp-rootpd.service
/usr/lib/systemd/system/hexagonrpcd-adsp-sensorspd.service
fastrpc user/group
```

This repo now includes dormant systemd service overlays and the FastRPC udev
rule. They are safe in images before the binary exists because the services use
`ConditionPathExists=/usr/bin/hexagonrpcd`.

## Sensor Firmware Task

PMOS splits the OnePlus SDM845 sensor files into
`firmware-oneplus-sdm845-sensors`. That subpackage installs the SDSP DSP files,
sensor registry, and symlinks:

```text
/usr/share/qcom/sdm845/OnePlus/oneplus6/dsp/sdsp
/usr/share/qcom/sdm845/OnePlus/oneplus6/sensors
/usr/share/qcom/sdm845/OnePlus/enchilada -> oneplus6
/usr/share/qcom/sdm845/OnePlus/fajita -> oneplus6
```

Until the Arch build reproduces that sensor firmware payload, `fastrpc` can load
and `iio-sensor-proxy` can run but accelerometer, light, proximity, and compass
will still be missing.

## Live Arch Prototype Check

The live `/dev/sda17` Arch prototype confirmed:

```text
/dev/fastrpc-adsp: present
/dev/fastrpc-cdsp: present
/dev/fastrpc-cdsp-secure: present
/dev/fastrpc-sdsp: present
/usr/share/qcom/sdm845/OnePlus: missing or empty
/usr/share/qcom/sdm845/OnePlus/oneplus6/sensors files: 0
hexagonrpcd: missing
hexagonrpcd unit files: 0
fastrpc user/group: missing
live build tools: git/gcc/make/pkg-config present; meson/ninja/kernel headers missing
```

So the next sensor move is packaging/injecting userspace and sensor firmware,
not another kernel-module hunt.
