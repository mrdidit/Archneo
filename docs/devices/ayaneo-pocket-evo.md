# AYANEO Pocket EVO

## Identity

- Archneo identifier: `ayaneo-pocket-evo`
- SoC/platform: Qualcomm SM8550
- Bring-up priority: second
- Current Archneo status: planned; untested

Pocket EVO support will reuse the Archneo SM8550 base established during
Pocket S 2K bring-up. It will remain a distinct device profile and will be
tested independently.

## ROCKNIX hardware source

The initial hardware description will be derived from ROCKNIX's
`qcs8550-ayaneo-pocketevo.dts`, which includes the same
`qcs8550-ayaneo-pocket-common.dtsi` platform description as the Pocket S 2K.

Source:
[ROCKNIX Pocket EVO device tree](https://github.com/ROCKNIX/distribution/blob/13e18947d2d41b17015f5df18405adefc4dfb2f5/projects/ROCKNIX/devices/SM8550/linux/dts/qcom/qcs8550-ayaneo-pocketevo.dts)

This revision is the shared SM8550 source baseline. EVO payload selection is
implemented for development, but the Pocket S 2K remains the only active
bring-up target. A complete independent hardware test matrix will be added
before the EVO is described as supported.
