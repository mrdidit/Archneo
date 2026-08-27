# AYANEO Pocket S 2K

## Identity

- Archneo identifier: `ayaneo-pocket-s-2k`
- SoC/platform: Qualcomm SM8550
- Bring-up priority: first
- Current Archneo status: image assembly passed; first hardware image black-screened before any recorded systemd activity

This page describes the original AYANEO Pocket S with the 2K display. It does
not describe the AYANEO Pocket S2, which uses SM8650.

## ROCKNIX hardware source

The initial hardware description will be derived from ROCKNIX's
`qcs8550-ayaneo-pockets2k.dts`, which includes the shared
`qcs8550-ayaneo-pocket-common.dtsi` platform description.

At the revision recorded below, the device tree describes:

- a dual-DSI `ayaneo,wt0600-2k` display panel;
- SGM3804 panel regulators;
- a SY7758 backlight controller; and
- a Goodix GT911 touchscreen with a 1440 by 2560 logical size.

Source:
[ROCKNIX Pocket S 2K device tree](https://github.com/ROCKNIX/distribution/blob/13e18947d2d41b17015f5df18405adefc4dfb2f5/projects/ROCKNIX/devices/SM8550/linux/dts/qcom/qcs8550-ayaneo-pockets2k.dts)

This revision is the selected first bring-up baseline. The build scripts record
it with the Linux source checksum and selected DTB in each artifact manifest.

## Bring-up record

The following evidence is required before changing the status from `untested`:

| Area | Status | Evidence |
| --- | --- | --- |
| Kernel/DTB compile | Passed | GitHub Actions run [`33063572182`](https://github.com/mrdidit/Archneo/actions/runs/33063572182), commit `c51aabe928b731370450c5f096c1fedd16311c29` |
| Android boot wrapper | Passed (dummy ramdisk only) | Artifact `archneo-ayaneo-pocket-s-2k-c51aabe928b731370450c5f096c1fedd16311c29` |
| Complete image assembly | Passed | GitHub Actions run [`33089290964`](https://github.com/mrdidit/Archneo/actions/runs/33089290964), commit `787ef0d8717b2248c9039f103a60e40144eff779`, artifact digest `459e0e0b0760419a1e259e8923102db3d923c4c963e5195426319dc0c1fcb955` |
| ABL prerequisite | Not recorded | Working ROCKNIX-ABL version required |
| ROCKNIX baseline | Not captured | Pending |
| ABL boot | Payload selected; kernel entry not proven | First removable-media test appeared to load `/KERNEL`; exact ABL version still required |
| Root/userspace | Failed to produce evidence | Correct UUID filesystems were present after forced power-off, but `/var/log/journal` had no files, `/var/lib/archneo` had no markers, and the home filesystem remained at its 1 GiB seed capacity |
| Diagnostic console | Failed | No visible console; UART not captured |
| Display/backlight | Black screen | Whether the panel backlight was electrically on was not recorded |
| Touchscreen | Not tested | Pending |
| Storage/USB | Not tested | Pending |
| Controls/rumble | Not tested | Pending |
| GPU | Not tested | Pending |
| Audio | Not tested | Pending |
| Wi-Fi/Bluetooth | Not tested | Pending |
| Battery/charging/fan | Not tested | Pending |
| Shutdown/suspend | Not tested | Pending |

Test logs must identify the image build, source revisions, device hardware
revision, test procedure, and observed result.

### First hardware attempt

- Date: 2026-08-27
- Image build: GitHub Actions run `33089290964`, commit `787ef0d`
- Write method: balenaEtcher to removable media
- Verified media state: GPT plus `ROCKNIX`, `ARCHNEO_ROOT`, and
  `ARCHNEO_HOME`; expected filesystem UUIDs matched the build profile
- Observation: ABL appeared to load the payload, the display showed no usable
  output, the device remained running, and shutdown required a hard power-off
- Post-test evidence: no persistent journal files and no Archneo first-boot
  marker; `/home` expansion had not completed
- Unknowns still to record: hardware revision, ROCKNIX-ABL version, whether
  the backlight was lit, and a known-good ROCKNIX comparison on the same unit

This result does not establish kernel entry. The next image changes only the
initramfs delivery: Archneo's archive is built into Linux and the Android
ramdisk returns to ROCKNIX's literal `dummy`.
