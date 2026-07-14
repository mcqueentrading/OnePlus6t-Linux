# Mobile Data And SIM Slot Selection

Last updated: 2026-07-03

The OnePlus 6T modem exposes two UIM/SIM slots through QMI. On the prototype,
after inserting a SIM, PMOS-style `qmicli` probing showed:

```text
Slot [1]: Card state: present
Slot [2]: Card state: error: no-atr-received
```

The working slot for this test was therefore slot 1.

The PMOS method is to select the first present USIM application as the Primary
GW provisioning session. The profile installs:

```text
/usr/local/bin/oneplus6t-uim-select
/etc/systemd/system/oneplus6t-uim-select.service
```

The script:

1. waits for `/dev/modem`, `/dev/wwan0qmi0`, or QRTR `qrtr://0`;
2. reads `--uim-get-card-status`;
3. finds the first `Card state: 'present'`;
4. extracts the first `usim (2)` application AID;
5. runs `--uim-change-provisioning-session` for Primary GW.

Prototype result:

```text
Primary GW: slot '1', application '1'
```

This only selects the SIM application. Full mobile data needs the native Arch
`ModemManager`/`libqmi` stack plus a stable APN/PDP attach path.

## Live SIM Test, 2026-07-03

With a SIM inserted in slot 1, direct QRTR `qmicli` probing on the Arch
prototype confirmed that the radio side is alive:

```text
Registration state: registered
CS: attached
PS: attached
Radio interface: lte
Current PLMN: redacted carrier test network
Signal: -82 dBm LTE
Operating mode: online
rmnet_ipa0: present
```

The local APN database contained a carrier-specific entry. Public images do not
ship this value:

```text
APN: <carrier-apn>
username: <carrier-user-if-required>
password: <carrier-password-if-required>
auth: pap
```

The modem also exposed a stored carrier 3GPP profile:

```text
profile: 2
APN: <stored-carrier-apn>
username: <stored-carrier-user>
password: <stored-carrier-password>
auth: pap
```

The temporary PMOS compatibility `qmicli` shim could read modem state, card
state, profiles, and signal strength, but all tested WDS network starts failed:

```text
3gpp-profile=2,ip-type=4
apn=<carrier-apn>,ip-type=4
apn=<carrier-apn>,username=<user>,password=<password>,auth=PAP,ip-type=4
apn=<stored-carrier-apn>,username=<user>,password=<password>,auth=PAP,ip-type=4

error: couldn't start network: QMI protocol error (70): 'InvalidOperation'
```

`rmnet_ipa0` remains present but has no IPv4 address:

```text
rmnet_ipa0 UNKNOWN fe80::200:ff:fe00:0/64
```

## Native ModemManager Test, 2026-07-03

After importing the PMOS SDM845 modules/firmware and rebooting into the Arch
root on `/dev/sda17`, native ModemManager detected the modem:

```text
path: /org/freedesktop/ModemManager1/Modem/0
manufacturer: QUALCOMM INCORPORATED
drivers: ipa, rpmsg_ctrl, qrtr
primary port: qrtr0
ports: qrtr0 (qmi), rmnet_ipa0 (net), rpmsg_ctrl3 (ignored)
state: registered
access tech: lte
operator id: redacted
operator name: redacted carrier
packet service state: attached
SIM slot paths: slot 1 present, slot 2 none active
```

NetworkManager then attempted a GSM connection using `qrtr0` and created a
`qmapmux0.0` data link, but ModemManager 1.24.2 crashed:

```text
device (qrtr0): Activation: starting connection 'carrier-mobile'
modem0/bearer1: net link qmapmux0.0 created
ModemManager.service: Main process exited, code=dumped, status=11/SEGV
```

Current conclusion: SIM selection, LTE registration, packet-service attach, and
the IPA/rmnet path are working. The open blocker is stable PDP/data-session
activation through native ModemManager/NetworkManager without the qmapmux
activation crash.

Calls and VoLTE are tracked separately in:

```text
docs/CALLS-VOLTE.md
```
