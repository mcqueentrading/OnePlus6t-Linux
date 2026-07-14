# hexagonrpcd Arch Package

This is the local Arch package recipe for the Qualcomm Hexagon FastRPC daemon
used by the OnePlus 6/6T sensor stack.

Upstream:

```text
https://github.com/linux-msm/hexagonrpc
```

PMOS/Alpine reference:

```text
https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/hexagonrpcd/APKBUILD
```

The OnePlus 6T release needs this package plus the
`firmware-oneplus-sdm845-sensors` payload before accelerometer, proximity,
ambient light, and magnetometer support can be marked working on Arch.

Do not add `hexagonrpcd` to `profiles/oneplus-fajita/packages.txt` until the
rootfs builder can build or inject this local package into its aarch64 pacman
root.
