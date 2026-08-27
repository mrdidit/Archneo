# AYANEO Pocket S 2K

## Identity

- Archneo identifier: `ayaneo-pocket-s-2k`
- SoC/platform: Qualcomm SM8550
- Bring-up priority: first
- Current Archneo status: planned; untested

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

The pinned revision above is an investigation baseline, not yet Archneo's
selected kernel revision. That selection will be recorded with the build
manifest.

## Bring-up record

The following evidence is required before changing the status from `untested`:

| Area | Status | Evidence |
| --- | --- | --- |
| Recovery route | Not tested | Pending |
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
