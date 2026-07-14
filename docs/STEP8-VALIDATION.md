# Step 8 Validation

Community Edition validation is scoped to the base install path and core device
bring-up. It intentionally avoids extra phone-shell polish.

## Must Keep

```text
boot/root images build
boot/root SHA-256 files are generated
fastboot can see the phone
quiet splash cmdline is present
Plymouth package/config is included
Hyprland starts with the stock-style config
USB SSH comes up
fixed 8GB ext4 root image is used
Wi-Fi scan path exists
modem/SIM tooling is present
audio services start
sensor backend services are present
```

## Out Of Scope

```text
custom lock screen
custom on-screen keyboard
custom power-key policy
screenshot chord
gesture launcher
custom compositor rotation plugin
advanced multimedia capture
```
