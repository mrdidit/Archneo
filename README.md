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

The initial target device and SoC are still being selected. Device-specific
code and flashing instructions will only be added after the boot chain,
partition layout, and recovery path have been documented and verified.

## Upstream projects

Archneo is an independent project and is not affiliated with Arch Linux ARM or
ROCKNIX. It intends to build on their work while preserving attribution and
complying with the licences of each imported component.

- [Arch Linux ARM](https://archlinuxarm.org/)
- [ROCKNIX](https://github.com/ROCKNIX/distribution)
- [ROCKNIX-ABL](https://github.com/ROCKNIX/abl)
