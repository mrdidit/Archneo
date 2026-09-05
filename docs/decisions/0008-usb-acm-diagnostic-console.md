# ADR 0008: Add a USB ACM diagnostic console for Pocket EVO

- Status: superseded for active bring-up by ADR 0010
- Date: 2026-09-05

## Context

The ADR 0007 Pocket EVO image was flashed successfully and its Android boot
image, checksums, root `PARTUUID`, appended DTB set, and built-in initramfs were
verified directly from the microSD card. The initramfs contained the executable
Archneo hook plus its FAT, block-device, and logging tools. After the hardware
attempt, however, neither `/archneo-diagnostics` on `ROCKNIX` nor a root marker
or journal existed.

That absence does not distinguish failure before the initramfs from an
initramfs that cannot enumerate or mount the SD controller. The EVO's USB-C
port is available when booting from microSD, and its pinned ROCKNIX device tree
describes the port as dual-role.

## Decision

The diagnostic image will additionally:

1. enable built-in `USB_CONFIGFS_ACM`, `USB_U_SERIAL`, `USB_F_ACM`, and
   `U_SERIAL_CONSOLE` support while relinking the diagnostic kernel;
2. retain the existing dual-role Qualcomm DWC3 configuration and the unmodified
   ROCKNIX Pocket EVO device tree;
3. add `console=ttyGS0,115200n8` after the existing `ttyMSM0` and `tty0`
   consoles;
4. request peripheral mode through both the generic USB-role class and the
   SM8550 DWC3 debugfs control at `/sys/kernel/debug/usb/a600000.usb/mode`;
5. create a configfs CDC ACM gadget named `Archneo Early Boot Console` from the
   built-in initramfs, wait up to 30 seconds for a UDC, and bind the first UDC;
6. keep FAT stage capture and its existing ABL-facing layout unchanged; and
7. route the diagnostic root's first-boot password setup and subsequent serial
   getty to `/dev/ttyGS0`.

The same next artifact also restores the pinned ROCKNIX recipe's
`DTC_FLAGS=-@` setting under ADR 0009. That boot-contract correction is
independent of the USB console itself.

The normal direct-root image does not enable or advertise this console. No ADB,
USB networking, mass-storage export, or preset password is added.

The Qualcomm debugfs fallback follows the same controller path used by
Thorch's SM8550 USB diagnostic gadget. It is a diagnostic dependency, not a
change to ABL or to the ROCKNIX device tree.

## Consequences

- A Linux host should enumerate `/dev/ttyACM0` if the kernel reaches the
  initramfs and the Pocket EVO USB device controller probes successfully.
- The late `ttyGS0` kernel console requests the printk backlog, providing
  evidence that predates configfs gadget creation.
- If root mounting fails after USB enumeration, mkinitcpio's emergency console
  should be reachable over the same physical link.
- If systemd starts, the password prompts for both `root` and `deck` occur on
  USB for this diagnostic image; there remain no default credentials.
- Failure to enumerate still cannot by itself prove that Linux never started,
  because the Qualcomm USB controller and Type-C role path are additional
  dependencies. FAT capture remains enabled as the parallel evidence path.
- The image modifies only removable media and does not install or update ABL.

## Supersession

The first hardware test containing this console and ADR 0009's corrected DTB
symbols still produced no FAT stage, root marker, journal, or `/home`
expansion. Its manifest confirmed that the functional initramfs was built into
Linux while the Android boot-image ramdisk remained `dummy`.

[ADR 0010](0010-external-diagnostic-initramfs.md) retains every USB-console
decision above but moves the exact same functional initramfs into the ramdisk
field of the removable SD card's `/KERNEL` file. It does not write an Android
or ABL partition.
