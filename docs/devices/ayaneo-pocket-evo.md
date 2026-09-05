# AYANEO Pocket EVO

## Identity

- Archneo identifier: `ayaneo-pocket-evo`
- SoC/platform: Qualcomm SM8550
- Bring-up priority: active
- Current Archneo status: image profile implemented; three unsuccessful
  removable-media attempts recorded

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

## Next controlled test

1. Follow [writing an Archneo removable image](../writing-removable-media.md)
   to verify and write
   `Archneo-ayaneo-pocket-evo-early-boot-diagnostic.img.gz` as a complete disk
   image.
2. Insert it into Pocket EVO, connect the EVO USB-C port to a Linux host with a
   data-capable cable, and monitor for `/dev/ttyACM0` before selecting Pocket
   EVO in ROCKNIX-ABL.
3. Open `/dev/ttyACM0` at 115200 baud if it appears. Record the complete output,
   whether password setup appears, and whether the device shuts down normally.
   Do not infer Linux boot merely from vibration.
4. After a forced stop or failed boot, mount both `ROCKNIX` and
   `ARCHNEO_ROOT` on another Linux system. Preserve `/archneo-diagnostics`
   from `ROCKNIX`, then `/var/lib/archneo` and `/var/log/journal` from the root
   before the next attempt.
5. If a TTY appears, set both requested passwords, log in as `deck`, and
   capture `sudo journalctl -b`, `sudo dmesg`, `/proc/device-tree/model`, and
   `systemctl --failed`.

## Validation matrix

| Area | Status | First evidence required |
| --- | --- | --- |
| ABL payload selection | Attempted; handoff unproven | ABL selection plus observed handoff |
| Kernel entry and ext4 root | No evidence from USB or microSD | USB ACM output, FAT initramfs stage, journal, or `/var/lib/archneo/userspace-reached` |
| Display/TTY | USB retained Qualcomm splash; microSD became black | visible first-boot password prompt |
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

## First hardware attempt

- Date reported: 2026-09-05
- Image: GitHub Actions run
  [`33961866086`](https://github.com/mrdidit/Archneo/actions/runs/33961866086),
  commit `57ca9142fc6c6e9b34158c824d1fcbded66aac78`
- Medium: removable USB storage connected to Pocket EVO
- Observation: the unit vibrated and remained on the Qualcomm splash; no
  Archneo TTY was visible
- Post-test evidence: both `/var/lib/archneo` and `/var/log/journal` on
  `ARCHNEO_ROOT` were empty, so there is no evidence that systemd/userspace
  ran
- Diagnostic limitation: the USB storage occupied the wired port, and this
  image does not configure ADB, USB serial, or USB networking
- Interpretation: neither vibration nor a retained firmware splash proves
  Linux entry. The kernel configuration contains built-in SCSI disk, USB
  storage, xHCI, Qualcomm DWC3, SD/MMC, and ext4 support, so the observation
  does not prove a missing USB-storage driver.
- Next controlled change: write the identical artifact to microSD, remove the
  USB storage, wait for first-boot work, then inspect the card for persistent
  userspace markers and journal files.

## Second hardware attempt

- Date reported: 2026-09-05
- Image: the same run `33961866086` artifact and commit `57ca9142`
- Medium: microSD; USB storage removed
- Observation: the unit vibrated and then changed from the Qualcomm splash to
  a black display
- Test duration: five minutes before forced shutdown
- Post-test evidence: both `/var/lib/archneo` and `/var/log/journal` were empty
- Interpretation: changing to the intended SD path changed the visible display
  state but still did not prove Linux entry, root mounting, or systemd startup
- Next controlled change: the ADR 0007 image adds a kernel-built-in diagnostic
  initramfs while retaining the full DTB set and EVO root `PARTUUID`; inspect
  `/archneo-diagnostics` on `ROCKNIX` after the test

## Third hardware attempt

- Date reported and inspected: 2026-09-05
- Image: GitHub Actions run
  [`33970427387`](https://github.com/mrdidit/Archneo/actions/runs/33970427387),
  commit `87b2f5cff98fef58c4bc8760b91bde89529940f1`
- Medium: microSD
- Post-test inspection: the FAT and both ext4 partitions were intact;
  `KERNEL.md5` and `KERNEL.sha256` passed; the manifest selected
  `qcs8550-ayaneo-pocketevo.dtb`, named all 14 appended DTBs, and used the root
  partition's exact GPT UUID
- Initramfs inspection: the FAT copy contained mkinitcpio's uncompressed early
  CPIO followed at byte 10240 by the gzip-compressed main archive; the main
  archive contained the executable `archneo-diagnostics` hook, `blkid`,
  `mount`, and `dmesg`
- Runtime evidence: no `/archneo-diagnostics` directory, root marker, journal,
  or `/home` expansion existed after the attempt
- Interpretation: image corruption, partition identity, and omission of the
  hook from the built artifact are ruled out. The result still cannot
  distinguish a pre-initramfs failure from failure to enumerate or mount the
  microSD inside the initramfs.
- Next controlled change: ADR 0008 adds a configfs CDC ACM console on `ttyGS0`
  while keeping the FAT evidence path active. ADR 0009 also restores
  ROCKNIX's omitted `DTC_FLAGS=-@` build setting and rejects symbol-less DTBs.
