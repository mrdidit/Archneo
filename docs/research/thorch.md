# Thorch implementation review

- Reviewed repository: [thorch-os/thorch](https://github.com/thorch-os/thorch)
- Reviewed revision: `82e7472e6cad5c08a55c3aef92ef5be218621b2c`
- Review date: 2026-09-05
- Scope: reusable SM8550 and ROCKNIX-ABL implementation details for Archneo

Thorch targets the AYN Thor, not the AYANEO Pocket EVO or Pocket S 2K. It is a
useful independent Arch Linux ARM implementation on the same SM8550 family,
but it is not a device-support source that can be copied wholesale into
Archneo.

## Findings adopted now

### Preserve DTB overlay symbols

Thorch passes `DTC_FLAGS=-@` when building the ROCKNIX `qcs8550-*.dtb` set and
its boot-image validator requires the appended device trees to contain
`__symbols__`. The pinned ROCKNIX kernel recipe uses the same compiler flag.
Archneo was not preserving it.

ADR 0009 corrects both the normal build and the diagnostic relink, and image
packaging now rejects any DTB that lacks the symbol table. This is a boot
contract fix, not a Thorch device patch.

References:

- [Thorch kernel build](https://github.com/thorch-os/thorch/blob/82e7472e6cad5c08a55c3aef92ef5be218621b2c/scripts/build-thorch-kernel.sh)
- [Thorch boot-image validator](https://github.com/thorch-os/thorch/blob/82e7472e6cad5c08a55c3aef92ef5be218621b2c/packages/thorch-bsp/payload/usr/lib/thorch/boot_image.py)

### Force the SM8550 USB peripheral role

Thorch's runtime RNDIS gadget writes `peripheral` to Qualcomm's
`/sys/kernel/debug/usb/a600000.usb/mode` control and also writes `device` to
the generic `/sys/class/usb_role/*/role` interface before binding a UDC.
Archneo's ADR 0008 early CDC ACM diagnostic now uses both role mechanisms. It
does not import RNDIS, SSH, ADB, or Thorch's userspace service.

Reference: [Thorch USB gadget](https://github.com/thorch-os/thorch/blob/82e7472e6cad5c08a55c3aef92ef5be218621b2c/packages/thorch-bsp/payload/usr/bin/thorch-usb-gadget)

## Findings retained for later evaluation

Thorch repacks an imported official ROCKNIX `KERNEL` template, preserving the
Android boot header values, and supplies its functional initramfs as the boot
image ramdisk. Archneo currently reproduces the pinned public ROCKNIX header
recipe and uses a built-in initramfs while Pocket EVO bring-up is isolated.
Thorch demonstrates that the external-ramdisk design is viable on AYN Thor; it
does not prove the same private ABL behavior on Pocket EVO. After the current
hardware test, an imported-template/external-ramdisk build is a controlled A/B
candidate rather than an immediate replacement.

Thorch's structural Android boot-image parser validates header layout,
ramdisk contents, appended FDT boundaries, overlay symbols, model selection,
command-line requirements, and root UUID. Archneo should gain equivalent
structural validation before release images and boot updates are supported.
Directly adapting that implementation would require GPL-2.0-or-later licence
compatibility and attribution.

Thorch also stages boot updates and preserves `KERNEL.previous`. Its update and
installer safety tests are useful design references for Archneo's later
internal-storage phase, but they do not alter the removable-media bring-up.

References:

- [Thorch ABL boot-image rebuild](https://github.com/thorch-os/thorch/blob/82e7472e6cad5c08a55c3aef92ef5be218621b2c/packages/thorch-bsp/payload/usr/bin/thorch-rebuild-abl-kernel)
- [Thorch update-safety notes](https://github.com/thorch-os/thorch/blob/82e7472e6cad5c08a55c3aef92ef5be218621b2c/docs/update-safety.md)
- [Thorch licence](https://github.com/thorch-os/thorch/blob/82e7472e6cad5c08a55c3aef92ef5be218621b2c/LICENSE)

## Package-repository finding

Thorch does not replace the installed system's package configuration with an
empty static-only configuration. It retains the Arch Linux ARM repository
layout, rewrites the mirror list to an Arch Linux ARM mirror, and adds only
`DisableSandboxFilesystem` to the installed configuration for its current
kernel limitation. Its unsigned local `[thorch]` file repository is appended
to a separate build-time pacman configuration used while assembling the image.

Archneo will continue to retain the official Arch Linux ARM `pacman.conf`; no
Thorch package repository is being added.

References:

- [Thorch image repository staging](https://github.com/thorch-os/thorch/blob/82e7472e6cad5c08a55c3aef92ef5be218621b2c/scripts/build-image.sh)
- [Thorch Arch Linux ARM mirror setup](https://github.com/thorch-os/thorch/blob/82e7472e6cad5c08a55c3aef92ef5be218621b2c/scripts/lib/common.sh)

## Deliberately not adopted

- AYN Thor device-tree patches, dual-display policy, MCU input mappings, RGB
  helpers, and board-specific kernel patches do not describe AYANEO hardware.
- Thorch's Btrfs default does not replace Archneo's requested ext4 root and
  home filesystems.
- Thorch's 512 MiB boot partition does not replace Archneo's deliberate 2 GiB
  `ROCKNIX` FAT32 partition.
- Thorch's account defaults, desktop stack, RNDIS/SSH diagnostic service, and
  internal installer are outside the current Pocket EVO early-boot test.
- Neither project flashes or replaces ROCKNIX-ABL as part of these image
  operations.
