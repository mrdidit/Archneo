# ADR 0004: Keep the functional initramfs inside the kernel

- Status: accepted
- Date: 2026-08-27

## Context

The public ROCKNIX SM8550 build links its functional appliance initramfs into
Linux through `CONFIG_INITRAMFS_SOURCE`. Its Android boot-image-v0 wrapper uses
the literal five-byte string `dummy` as the external ramdisk. Whether the
non-public LinuxLoader used by ROCKNIX-ABL forwards a functional external
ramdisk is not publicly verifiable.

Archneo's first complete image reversed that arrangement: the kernel had an
empty built-in initramfs and the Android ramdisk contained an Archneo
mkinitcpio archive. ABL appeared to select the removable payload on a Pocket S
2K, but the device remained on a black screen and required forced power-off.
The root filesystem subsequently contained no systemd journal or first-boot
marker evidence. Media labels and filesystem UUIDs were correct.

This test did not prove kernel entry or identify the private loader as the
cause, but it removed the basis for treating external-initramfs forwarding as
part of the established ABL contract.

## Decision

Complete Archneo images link the generated mkinitcpio `.cpio.gz` archive into
the kernel and retain ROCKNIX's literal `dummy` in the Android ramdisk field.
Root discovery remains UUID-based. The compile-smoke kernel continues to have
an empty built-in initramfs, so it remains distinct from a bootable artifact.

The image builder relinks `Image` after rootfs preparation without rebuilding
or changing the already installed kernel modules. The kernel release remains
unchanged. A standalone copy of the exact archive is retained on the FAT
filesystem for build inspection; ABL is not expected to load that file.

## Consequences

- The next hardware test changes only initramfs delivery, retaining the single
  Pocket S 2K DTB, command line, UUIDs, and partition layout.
- Archneo no longer depends on an unverified private-loader behaviour for its
  essential early userspace.
- Complete-image kernel linking must happen after mkinitcpio generation.
- A continued black screen will move the next investigation toward kernel
  entry, single-DTB acceptance, display initialization, and serial capture.
- No ABL binary, setting, or internal-storage partition is changed.
