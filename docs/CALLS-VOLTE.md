# Calls And VoLTE Notes

Last updated: 2026-07-03

This file tracks the call/VoLTE path separately from mobile data. On the
OnePlus 6T, mobile data can register and attach while voice calling still needs
IMS/VoLTE userspace.

## User-Provided PMOS Reference

Known OnePlus 6T bring-up notes from the PMOS side:

```text
Android setup state:
- If msmtool leaves Android showing only 16 GB instead of 128 GB UFS, enable OEM
  unlocking, unlock the bootloader, let the unlock wipe the device, reboot back
  to fastboot, run fastboot erase userdata, boot recovery, and wipe again.
- Boot Android, set up the device, sideload EngineerMode and OnePlus LogKit.
- Use dialer code *#800#, run with EngineerMode, then go to OnePlus LogKit
  feature switches and enable VoLTE and VoWiFi.
- Reboot with a SIM inserted and verify VoLTE in Android before flashing Linux.

postmarketOS side:
- Install 81voltd.
- Enable 81voltd with OpenRC or systemd.
- Set mobile network mode to include 4G.
- Reboot, then restart 81voltd after the modem appears.
- PipeWire is recommended for call audio instead of PulseAudio.
```

Do not run the Android wipe or `fastboot erase userdata` steps on the current
Arch prototype unless the project intentionally returns to a stock Android
setup state. Those steps are destructive and belong in a separate recovery
or factory-prep workflow.

## Arch Implications

Current Arch state:

```text
ModemManager sees qrtr0/rmnet_ipa0
SIM slot 1 is present
LTE registration works
packet-service attach works
PDP data attach still crashes ModemManager 1.24.2
PipeWire Pro Audio profile is available
```

Arch tasks before calls are realistic:

1. Fix stable mobile data/PDP attach.
2. Identify whether `81voltd` can be packaged for Arch Linux ARM or replaced
   with an equivalent IMS/VoLTE service.
3. Preserve or document any Android-side modem provisioning that must happen
   before Linux installation.
4. Validate PipeWire call audio routing separately from normal media playback.
5. Test with a SIM that has VoLTE provisioned by the carrier.

## Release Policy

Calls should not block the first public Arch phone installer if Wi-Fi, display,
touch, battery, terminal, OSK, and mobile data are usable. Calls/VoLTE should be
published as a marked experimental milestone until the IMS service and audio
routing are reproducible.
