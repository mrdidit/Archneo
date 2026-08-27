# Archneo

Archneo is an experimental Arch Linux ARM distribution for ARM gaming
handhelds. It aims to combine an Arch userspace with device support derived
from ROCKNIX and a ROCKNIX-ABL-compatible boot layout.

> [!WARNING]
> Archneo is at the research and bring-up stage. It does not yet produce a
> bootable image. Do not flash bootloader components from this repository to a
> device.

## Goals

- Build a minimal, reproducible Arch Linux ARM root filesystem.
- Reuse the appropriate upstream and ROCKNIX kernel device support.
- Package the kernel, device trees, modules, and firmware needed per device.
- Produce images that follow the ROCKNIX-ABL boot contract.
- Document backup, recovery, installation, and uninstallation procedures.

## Status

The initial platform is Qualcomm SM8550. Device bring-up will proceed in this
order:

1. AYANEO Pocket S 2K (`ayaneo-pocket-s-2k`)
2. AYANEO Pocket EVO (`ayaneo-pocket-evo`)

The similarly named AYANEO Pocket S2 is an SM8650 device and is not one of
these initial targets. Archneo does not yet produce a bootable image.

See the [documentation index](docs/README.md) and [bring-up roadmap](docs/roadmap.md)
for the current plan and evidence requirements.

Device-specific code and flashing instructions will only be added after the
boot chain, partition layout, and recovery path have been documented and
verified.

## Upstream projects

Archneo is an independent project and is not affiliated with Arch Linux ARM or
ROCKNIX. It intends to build on their work while preserving attribution and
complying with the licences of each imported component.

- [Arch Linux ARM](https://archlinuxarm.org/)
- [ROCKNIX](https://github.com/ROCKNIX/distribution)
- [ROCKNIX-ABL](https://github.com/ROCKNIX/abl)
