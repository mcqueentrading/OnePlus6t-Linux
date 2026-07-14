# Native Userspace Packages

Community Edition installs only the base runtime layer needed to boot, display a
Hyprland session, expose core hardware services, and keep the phone reachable.

The package manifest is:

```text
profiles/oneplus-fajita/packages.txt
```

Current package groups:

```text
display/input base
Qualcomm firmware
audio services
networking
Bluetooth userspace
battery reporting
sensor backend
modem/SMS/mobile-data tooling
```

Custom lock-screen, custom keyboard, screenshot-chord, gesture-launcher, and
other shell polish are intentionally not part of this edition.
