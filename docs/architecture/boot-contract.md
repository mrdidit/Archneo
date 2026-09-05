# ROCKNIX-ABL boot contract

This document separates facts visible in the public ROCKNIX build system from
assumptions that still require an Archneo hardware test. The distinction is
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
| First partition | GPT name `system`; 2048 MiB FAT, label `ROCKNIX`, GPT legacy-boot attribute |
| First-partition payload | `/KERNEL`, `/SYSTEM`, and checksum files |
| Second partition | ext4, label `STORAGE` |

The `/KERNEL` file is an Android boot image with header version 0. ROCKNIX
constructs it as follows:

1. gzip the arm64 Linux `Image`;
2. append the built DTB set to that gzip file;
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

## Active Pocket EVO compatibility profile

The Pocket EVO image follows the SM8550 envelope reported booting on Pocket S
2K while changing only the parts needed for an ordinary Arch installation.
The report is evidence about the shared ABL format, not evidence that EVO
boots:

| Item | Active Archneo value | Reason |
| --- | --- | --- |
| Media | removable card only | avoids internal-storage writes |
| FAT geometry | same as pinned ROCKNIX | minimize loader variables |
| FAT label | `ROCKNIX` | required ROCKNIX-ABL compatibility contract |
| FAT GPT name | `system` | match the removable ROCKNIX/Pocknix ABL layout |
| Boot payload | `/KERNEL`, `/KERNEL.md5`, `/KERNEL.sha256` | ABL compatibility plus Archneo provenance |
| DTBs in payload | complete pinned ROCKNIX SM8550 set | let ABL select the Pocket EVO model from the established layout |
| Root partition | 30 GiB ext4 | normal writable Arch root |
| Home partition | ext4 seed, expanded to remaining media | independent user data without Btrfs |
| Kernel-built-in initramfs | none | remove early userspace from this controlled test |
| Android boot-image ramdisk | valid empty `newc` archive | preserve a valid boot-image field without a second root environment |
| Root command line | `root=PARTUUID=… rootfstype=ext4 rw rootwait` | use the identifier Linux can resolve before userspace |
| Systemd target | `multi-user.target` | reach TTY credential setup before graphical work |
| Console | `ttyMSM0` and `tty0`, verbose logging | early bring-up evidence |

The direct-root values above remain the ordinary image profile. After both USB
and microSD EVO tests produced no userspace evidence, the next workflow
artifact uses the controlled diagnostic exception in
[ADR 0007](../decisions/0007-early-boot-diagnostic-initramfs.md): a functional
initramfs is linked into Linux, the Android ramdisk is ROCKNIX's literal
`dummy`, the root remains the same `PARTUUID`, and early stages are written to
the `ROCKNIX` FAT filesystem. After the first test produced no FAT stage file,
[ADR 0008](../decisions/0008-usb-acm-diagnostic-console.md) added a
diagnostic-only CDC ACM `ttyGS0` console without changing that ABL envelope.

`make kernel` builds the common Linux image, modules, and every DTB represented
by the pinned ROCKNIX SM8550 `.dts` files. Packaging concatenates those DTBs in
locale-independent filename order. The essential Qualcomm SDHCI/MMC,
devtmpfs, and ext4 paths are built in, so Linux can mount the root partition
without loading a module or running an initramfs.

The first hardware image placed an Archneo initramfs in the Android ramdisk;
the second linked it into Linux. Both remained on a black screen and produced
no journal or first-boot marker after forced power-off. The built-in experiment
is recorded in [ADR 0004](../decisions/0004-built-in-initramfs.md); the active
direct-root response is [ADR 0005](../decisions/0005-direct-root-abl-parity.md).

The removable image uses stable, machine-readable filesystem and partition
UUIDs from the selected file in
[`config/devices`](../../config/devices). `/etc/fstab` names `/boot`, `/`, and
`/home` by filesystem UUID. The final home partition expands on first boot
without regenerating its UUID. Only the pre-userspace `root=` argument uses the
root GPT UUID. The FAT label remains `ROCKNIX` regardless of its FAT filesystem
UUID or its separate GPT name, `system`.

## External Pocket S 2K boot evidence

On 2026-08-28, a collaborator reported that the Pocknix SM8550 image boots on
Pocket S 2K after that model is selected in ROCKNIX-ABL. Audio was not working.
Pocknix appends the full SM8550 DTB set and mounts its root directly without a
functional initramfs. This report establishes a useful compatible envelope,
not Archneo support: the exact tested Pocknix artifact and ABL version have not
yet been recorded, and its userspace falls back to RP6 board settings.

## Hardware questions still open

The next controlled Pocket EVO boot must establish:

- whether Archneo's matching appended-DTB envelope reaches Linux;
- whether Linux mounts the intended ext4 root by GPT UUID;
- whether systemd reaches the `tty1` password setup; and
- where useful loader and early-kernel diagnostics can be captured if it does
  not.

Archneo will not experiment with an alternative FAT label or a smaller initial
FAT partition: `ROCKNIX` and 2048 MiB are part of the project's conservative
ABL compatibility profile. The multi-DTB payload remains bring-up evidence,
not a declaration that every included board is supported. The corresponding
machine-readable constants are in
[`config/platform.env`](../../config/platform.env).
