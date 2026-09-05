# ADR 0008: Add a USB ACM diagnostic console for Pocket EVO

- Status: accepted for the next diagnostic image
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
4. create a configfs CDC ACM gadget named `Archneo Early Boot Console` from the
   built-in initramfs, wait up to 30 seconds for a UDC, and bind the first UDC;
5. keep FAT stage capture and its existing ABL-facing layout unchanged; and
6. route the diagnostic root's first-boot password setup and subsequent serial
   getty to `/dev/ttyGS0`.

The normal direct-root image does not enable or advertise this console. No ADB,
USB networking, mass-storage export, or preset password is added.

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
