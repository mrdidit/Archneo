# AYANEO Pocket EVO

## Identity

- Archneo identifier: `ayaneo-pocket-evo`
- SoC/platform: Qualcomm SM8550
- Bring-up priority: active
- Current Archneo status: image profile implemented; hardware untested

Pocket EVO reuses the Archneo SM8550 base established during Pocket S 2K work
but remains a distinct device profile with independent media identities and
test results. A Pocket EVO is physically available for local iteration as of
2026-09-05. No successful Archneo boot has yet been claimed.

## ROCKNIX hardware source

The initial hardware description will be derived from ROCKNIX's
`qcs8550-ayaneo-pocketevo.dts`, which includes the same
`qcs8550-ayaneo-pocket-common.dtsi` platform description as the Pocket S 2K.

Source:
[ROCKNIX Pocket EVO device tree](https://github.com/ROCKNIX/distribution/blob/13e18947d2d41b17015f5df18405adefc4dfb2f5/projects/ROCKNIX/devices/SM8550/linux/dts/qcom/qcs8550-ayaneo-pocketevo.dts)

At the pinned revision, the EVO DTS identifies the model as `AYANEO Pocket
EVO`, with compatible strings `ayaneo,pocketevo`, `qcom,qcs8550`, and
`qcom,sm8550`. It describes a single-DSI Chipone ICNA3512 panel rotated 270
degrees and a FocalTech FT5426 touchscreen at 1080×1920. Those are source
descriptions, not claims that the drivers work in Archneo.

## Active image profile

The default `make kernel` and `sudo make image` targets now select
`ayaneo-pocket-evo`. The resulting image:

- uses `qcs8550-ayaneo-pocketevo.dtb` as its recorded target while appending
  every pinned ROCKNIX SM8550 DTB for ABL selection;
- retains the 2 GiB FAT32 `system` partition labelled `ROCKNIX`;
- uses EVO-specific filesystem UUIDs and GPT partition UUIDs;
- mounts its 30 GiB ext4 root directly by GPT `PARTUUID`;
- expands the final ext4 `/home` partition on first boot;
- starts in `multi-user.target` and asks for separate `root` and `deck`
  passwords on `tty1`; and
- enables NetworkManager without preconfiguring a wireless network.

The image only writes removable media. It neither contains nor replaces
ROCKNIX-ABL.

## First controlled test

1. Follow [writing an Archneo removable image](../writing-removable-media.md)
   to verify and write `Archneo-ayaneo-pocket-evo.img.gz` as a complete disk
   image.
2. Safely eject it, insert it into Pocket EVO, and select Pocket EVO in
   ROCKNIX-ABL.
3. Record whether the panel changes, the TTY password setup appears, and the
   device shuts down normally. Do not infer Linux boot merely from vibration.
4. After a forced stop or failed boot, mount `ARCHNEO_ROOT` on another Linux
   system and preserve `/var/lib/archneo` plus `/var/log/journal` before the
   next attempt.
5. If a TTY appears, set both requested passwords, log in as `deck`, and
   capture `sudo journalctl -b`, `sudo dmesg`, `/proc/device-tree/model`, and
   `systemctl --failed`.

## Validation matrix

| Area | Status | First evidence required |
| --- | --- | --- |
| ABL payload selection | Untested | ABL selection plus observed handoff |
| Kernel entry and ext4 root | Untested | journal or `/var/lib/archneo/userspace-reached` |
| Display/TTY | Untested | visible first-boot password prompt |
| Touchscreen | Untested | evdev device and coordinate test |
| Internal/removable storage | Untested | `lsblk`, mount, and I/O observations |
| Controls and rumble | Untested | input-device/event mapping |
| GPU | Untested | driver log and renderer after TTY milestone |
| Audio | Untested | codec/card discovery and playback test |
| Wi-Fi/Bluetooth | Untested | NetworkManager/Bluetooth discovery |
| Battery/charging/thermal | Untested | power-supply and thermal sysfs data |
| Suspend/shutdown | Untested | repeatable cold boot and power transition |

The complete matrix must be filled from Pocket EVO observations before the
device is described as supported.
