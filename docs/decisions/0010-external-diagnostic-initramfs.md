# ADR 0010: Deliver the diagnostic initramfs in the removable KERNEL ramdisk

- Status: accepted for the next diagnostic image
- Date: 2026-09-05

## Context

The Pocket EVO artifact from GitHub Actions run `33978519750`, commit
`76d207f28dee952ee94836993337a5961ffdb0d6`, retained ROCKNIX's literal
`dummy` Android ramdisk and linked the functional diagnostic initramfs into
Linux. Its post-test card inspection found valid MD5 and SHA-256 checksums, all
14 symbol-bearing SM8550 DTBs, the correct EVO/root identities, and the
`ttyGS0` command line. It found no FAT diagnostic stage, root initramfs marker,
journal, populated machine ID, or `/home` expansion.

That result provides no evidence that the built-in initramfs ran. Thorch's
independent SM8550 ABL implementation uses a functional external Android
ramdisk on AYN Thor. An earlier Archneo Pocket S 2K image also tried an
external initramfs, but it preceded the full DTB set, DTB-symbol correction,
EVO profile, and built-in USB diagnostic drivers. Repeating only the delivery
change in the current envelope is therefore a controlled Pocket EVO test.

“Android boot image” describes the container format of `/KERNEL` on removable
media. It does not mean Android's internal `boot` or `vendor_boot` partition.

## Decision

The next Pocket EVO diagnostic image will:

1. keep `CONFIG_INITRAMFS_SOURCE` empty;
2. retain configfs, Qualcomm DWC3 dual-role, CDC ACM, USB serial-console, and
   debugfs support as kernel built-ins;
3. put the generated Archneo mkinitcpio archive in the Android boot-image-v0
   ramdisk field of `/KERNEL` on the SD card;
4. retain the complete 14-DTB, `DTC_FLAGS=-@`, root `PARTUUID`, FAT
   diagnostics, `console=ttyGS0`, and first-boot USB-getty settings;
5. structurally verify that the generated boot image contains the exact
   kernel field, exact initramfs, command line, arm64 Image, and expected
   symbol-bearing DTB count; and
6. keep a standalone copy of the initramfs on the FAT filesystem for
   post-build inspection.

The structural validator is an independent Archneo implementation. It does
not copy Thorch's GPL-2.0-or-later source.

The image builder writes only its output disk-image file. It contains no ADB,
Fastboot, internal-device path, ABL installer, or command that writes Android
partitions. ROCKNIX-ABL remains an already-installed external prerequisite.

## Consequences

- If ABL forwards the external ramdisk and Linux enters it, the hook can bind
  `Archneo Early Boot Console`; the connected Linux host should then create
  `/dev/ttyACM0`.
- The kernel console backlog, initramfs emergency shell, `root`/`deck`
  password setup, and subsequent serial getty share that link.
- A missing USB device remains ambiguous between failure before initramfs and
  failure of the USB controller/role path, so FAT capture remains enabled.
- Removing the SD card returns the device to its existing Android/ABL state;
  no internal partition is read, formatted, or written by this workflow.
