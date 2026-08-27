# AYANEO Pocket S 2K

## Identity

- Archneo identifier: `ayaneo-pocket-s-2k`
- SoC/platform: Qualcomm SM8550
- Bring-up priority: first
- Current Archneo status: kernel compile/package passed; full image and hardware untested

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
| Complete image assembly | Reached rootfs package update | Runs [`33071305455`](https://github.com/mrdidit/Archneo/actions/runs/33071305455), [`33074171748`](https://github.com/mrdidit/Archneo/actions/runs/33074171748), and [`33079249905`](https://github.com/mrdidit/Archneo/actions/runs/33079249905): usr-merge issue fixed; latest stopped at Pacman Landlock under qemu-user; scoped correction awaiting CI |
| ABL prerequisite | Not recorded | Working ROCKNIX-ABL version required |
| ROCKNIX baseline | Not captured | Pending |
| ABL boot | Not tested | Pending |
| Diagnostic console | Not tested | Pending |
| Display/backlight | Not tested | Pending |
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
