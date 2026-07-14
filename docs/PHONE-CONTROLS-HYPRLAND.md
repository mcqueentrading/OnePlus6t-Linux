# Phone Controls

Community Edition keeps the Hyprland layer generic. It ships a stock-style
Hyprland config and a neutral Lua companion file instead of the tuned phone
shell config from the development branch.

It does not ship custom lock-screen, on-screen-keyboard, screenshot-chord,
power-key, gesture-launcher, or compositor auto-rotation helpers.

## Hyprland Base

The profile installs:

```text
~/.config/hypr/hyprland.conf
~/.config/hypr/hyprland.lua
/usr/local/bin/start-hyprland
```

The default session uses generic Hyprland monitor selection:

```text
monitor = , preferred, auto, auto
```

## Sensor Backend

The sensor backend remains in scope so apps or downstream shells can use it:

```text
hexagonrpcd-adsp-sensorspd.service
firmware-oneplus-sdm845-sensors
OnePlus 6T libssc mount matrix
iio-sensor-proxy
```

Downstream builds can add rotation policy later without changing that backend.
