# ROCKNIX-ABL boot contract

This document separates facts visible in the public ROCKNIX build system from
assumptions that still require a Pocket S 2K hardware test. The distinction is
important: the public [`ROCKNIX/abl`](https://github.com/ROCKNIX/abl)
repository publishes signed binaries, but its release workflow builds the
loader from the non-public `ROCKNIX/LinuxLoader` repository. Archneo therefore
treats an already-installed ROCKNIX-ABL as an external interface.

ABL installation, replacement, and restoration are outside Archneo's scope.
No Archneo build or initial test procedure writes internal storage.

## Pinned investigation baseline

| Component | Revision |
| --- | --- |
| ROCKNIX distribution | `13e18947d2d41b17015f5df18405adefc4dfb2f5` |
| ROCKNIX-ABL release | `v1.1.8` |
| LinuxLoader revision named by that release | `22ac43cef216dfd2caefef26cd46db0d8e0d4d71` |
| Linux | `7.2` |

The machine-readable pins and archive checksums are in
[`config/sources.env`](../../config/sources.env).

## Confirmed public build behaviour

The pinned ROCKNIX SM8550 profile selects `BOOTLOADER="qcom-abl"`. Its image
builder emits this removable-media layout:

| Item | ROCKNIX output |
| --- | --- |
| Partition table | GPT |
| First partition start | sector `32768` (16 MiB at 512-byte sectors) |
| First partition | 2048 MiB FAT, label `ROCKNIX`, GPT legacy-boot attribute |
| First-partition payload | `/KERNEL`, `/SYSTEM`, and checksum files |
| Second partition | ext4, label `STORAGE` |

The `/KERNEL` file is an Android boot image with header version 0. ROCKNIX
constructs it as follows:

1. gzip the arm64 Linux `Image`;
2. append built DTBs to that gzip file;
3. use the literal five-byte string `dummy` as the ramdisk;
4. set kernel, ramdisk, and tags offsets to zero;
5. set Android OS version `12.0.0`; and
6. place the Linux command line in the boot-image header.

These statements describe what the public image builder produces. They do not
prove which fields the private loader actually requires.

Relevant pinned sources:

- [SM8550 options](https://github.com/ROCKNIX/distribution/blob/13e18947d2d41b17015f5df18405adefc4dfb2f5/projects/ROCKNIX/devices/SM8550/options)
- [qcom-ABL kernel packaging](https://github.com/ROCKNIX/distribution/blob/13e18947d2d41b17015f5df18405adefc4dfb2f5/projects/ROCKNIX/packages/linux/package.mk)
- [disk image construction](https://github.com/ROCKNIX/distribution/blob/13e18947d2d41b17015f5df18405adefc4dfb2f5/scripts/mkimage)

## Initial Archneo compatibility profile

The first Pocket S 2K image will change only the parts needed for an ordinary
Arch installation:

| Item | Initial Archneo value | Reason |
| --- | --- | --- |
| Media | removable card only | avoids internal-storage writes |
| FAT geometry | same as pinned ROCKNIX | minimize loader variables |
| FAT label | `ROCKNIX` | required ROCKNIX-ABL compatibility contract |
| Boot payload | `/KERNEL` | matches public ROCKNIX layout |
| DTB in payload | Pocket S 2K only | make the first artifact unambiguous |
| Root partition | ext4, label `ARCHNEO_ROOT` | normal writable Arch root |
| Embedded initramfs | none | ROCKNIX's appliance `/init` is not usable as Arch's root |
| Boot command line | `boot=LABEL=ROCKNIX disk=LABEL=ARCHNEO_ROOT` | preserve the ROCKNIX-ABL-facing convention |
| Root command line | `root=LABEL=ARCHNEO_ROOT rootfstype=ext4 rw rootwait` | direct ext4 root mount |
| Console | `ttyMSM0` and `tty0`, verbose logging | early bring-up evidence |

The inherited kernel configuration builds the Qualcomm SDHCI/MMC path and
ext4 into the kernel, so a direct root mount does not depend on modules from an
unmounted filesystem.

## Hardware questions still open

The first controlled boot must establish:

- whether the 16 MiB offset and 2048 MiB FAT size are required or merely
  ROCKNIX defaults;
- how ABL identifies and selects appended DTBs;
- whether a single appended Pocket S 2K DTB is accepted; and
- where useful loader and early-kernel diagnostics can be captured.

Archneo will not experiment with an alternative FAT label: `ROCKNIX` is part
of the project's ABL compatibility contract. Until the remaining evidence
exists, a smaller FAT partition and multi-device payloads are experiments
rather than supported formats. The corresponding machine-readable constants
are in [`config/platform.env`](../../config/platform.env).
