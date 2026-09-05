# ADR 0007: Add an early-boot diagnostic initramfs for Pocket EVO

- Status: accepted for the next diagnostic image
- Date: 2026-09-05

## Context

The first Pocket EVO artifact was tested from USB storage and microSD. The USB
attempt vibrated and retained the Qualcomm splash. The microSD attempt vibrated
and changed to a black display. After five minutes and a forced shutdown, both
tests left `/var/lib/archneo` and `/var/log/journal` empty on the ext4 root.

Those results provide no evidence that systemd ran. The direct-root image has
no process before the real root's `/sbin/init`, so it also has nowhere to save
root-discovery failures or early kernel logs. Repeating display changes would
not distinguish kernel entry, device-tree selection, root mounting, and DRM.

## Decision

The next Pocket EVO artifact is an explicitly named early-boot diagnostic
image. The ordinary direct-root image target remains available. The diagnostic
variant:

1. keeps the installed ROCKNIX-ABL unchanged;
2. retains the `system` GPT name, 2 GiB FAT32 `ROCKNIX` filesystem, full 14-DTB
   SM8550 set, EVO profile UUIDs, and ext4 root `PARTUUID`;
3. links a generated mkinitcpio archive into Linux through
   `CONFIG_INITRAMFS_SOURCE`;
4. keeps the Android boot-image ramdisk as ROCKNIX's literal `dummy`;
5. adds `boot=LABEL=ROCKNIX rd.debug rd.log=all`; and
6. records initramfs stages, block discovery, selected device-tree identity,
   DRM state, and `dmesg` below `/archneo-diagnostics` on the FAT filesystem.

The exact built-in archive is also copied to the FAT filesystem and its digest
is recorded in the build manifest.

## Consequences

- A FAT stage file proves Linux entered the built-in initramfs even if the real
  root never mounts.
- A root-stage or emergency file narrows the failure without requiring a
  working display or network.
- No FAT diagnostic directory means the kernel did not reach the hook or could
  not enumerate/mount the FAT filesystem; physical UART remains the next
  independent observation path.
- This diagnostic artifact is not a release configuration or hardware-support
  claim.
