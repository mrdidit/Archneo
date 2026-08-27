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
| Root partition | 30 GiB ext4 | normal writable Arch root |
| Home partition | ext4 seed, expanded to remaining media | independent user data without Btrfs |
| Kernel-built-in initramfs | Archneo mkinitcpio `.cpio.gz` | retain ROCKNIX's proven functional-initramfs location |
| Android boot-image ramdisk | literal five-byte `dummy` | avoid depending on private ABL to forward an external initramfs |
| Boot command line | `boot=LABEL=ROCKNIX` | preserve the ABL-facing label convention |
| Root command line | `disk=UUID=… root=UUID=… rootfstype=ext4 rw rootwait` | avoid unstable device paths and partition identifiers |
| Console | `ttyMSM0` and `tty0`, verbose logging | early bring-up evidence |

The compile-smoke artifact deliberately retains ROCKNIX's five-byte `dummy`
ramdisk and an empty built-in initramfs to validate compilation and
Android-container packaging. It is not the bootable Archneo artifact. Complete
images relink the kernel with an Archneo mkinitcpio archive using the `udev`,
`block`, `filesystems`, and `fsck` hooks, while leaving the Android boot-image
ramdisk as `dummy`. The kernel still builds the essential Qualcomm SDHCI/MMC
and ext4 paths in, but built-in early userspace is responsible for resolving
`root=UUID=…`.

The first hardware image instead placed that archive in the Android ramdisk
field. ABL appeared to select the payload, but the device remained on a black
screen and the root filesystem contained no journal or first-boot markers
after forced power-off. That test did not prove that private LinuxLoader passes
an external ramdisk to Linux. [ADR 0004](../decisions/0004-built-in-initramfs.md)
therefore restores the public ROCKNIX packaging boundary for the next test.

The removable image uses stable, machine-readable filesystem UUIDs from
[`config/platform.env`](../../config/platform.env). `/etc/fstab` names `/boot`,
`/`, and `/home` by filesystem UUID. The final home partition expands on first
boot without regenerating its UUID. The FAT label remains `ROCKNIX` regardless
of its FAT filesystem UUID.

## Hardware questions still open

The first controlled boot must establish:

- how ABL identifies and selects appended DTBs;
- whether a single appended Pocket S 2K DTB is accepted; and
- where useful loader and early-kernel diagnostics can be captured.

Archneo will not experiment with an alternative FAT label or a smaller initial
FAT partition: `ROCKNIX` and 2048 MiB are part of the project's conservative
ABL compatibility profile. Multi-device payloads remain experiments rather
than supported formats. The corresponding machine-readable constants are in
[`config/platform.env`](../../config/platform.env).
