# Pocket S 2K black-screen diagnostic image

> [!NOTE]
> This procedure applies to the built-in-initramfs diagnostic branch at commit
> `e95e9c32aadf3cd8e34be5bf7ad5f0c22730da5b`. ADR 0005 supersedes it for the
> active bring-up image with an initramfs-free direct root. That newer image
> cannot create the mkinitcpio FAT stage files described below.

## Purpose

The reported Pocket S 2K symptom is a black display with a vibration during
startup. No white screen was observed, and no Linux console or panic output was
visible. The exact image identity and post-test filesystem evidence remain to
be recorded.

Power-on and vibration establish neither Linux entry nor successful display
initialization because both may originate in ABL or earlier firmware. Likewise,
a black panel cannot distinguish an early boot failure from a working Linux
system whose DRM, DSI, panel, backlight, or framebuffer-console path failed.

This diagnostic image keeps the accepted ROCKNIX device tree and built-in
initramfs arrangement unchanged. It adds only observability:

- mkinitcpio stage and emergency logs written directly to the `ROCKNIX` FAT
  filesystem before the real root is mounted;
- `rd.debug` and `rd.log=all` for complete mkinitcpio tracing;
- `drm.debug=0x1ff` and a 4 MiB kernel log buffer;
- one-second persistent-journal synchronization; and
- kernel, systemd, regulator, and DRM snapshots at 0, 5, 15, 30, and 60
  seconds after systemd starts the capture service.

It does not include the unverified dummy panel-regulator patch from the
`Testing` branch.

## Test procedure

1. Record the Git commit, Actions run, artifact name, device hardware revision,
   and ROCKNIX-ABL version.
2. Write the diagnostic image to removable media and boot it through the
   existing ROCKNIX-ABL installation.
3. Record the timing of vibration and any display or backlight change.
4. Leave the device powered for at least 75 seconds, even if the panel remains
   black, then force power-off only if normal shutdown remains unavailable.
5. Return the card to a Linux workstation and mount `ARCHNEO_ROOT` read-only if
   practical.

## Recovering evidence

Replace the path below with the actual `ARCHNEO_ROOT` mount point:

```bash
root=/run/media/$USER/ARCHNEO_ROOT
boot=/run/media/$USER/ROCKNIX
sudo find "$boot/archneo-diagnostics" -maxdepth 3 -type f -ls
sudo ls -la "$root/var/lib/archneo"
sudo find "$root/var/lib/archneo/diagnostics" -maxdepth 2 -type f -ls
sudo journalctl --directory="$root/var/log/journal" --list-boots
sudo journalctl --directory="$root/var/log/journal" --boot=0 --dmesg --no-pager
```

The FAT diagnostic directory can contain these stage files:

- `initramfs-before-root.log`: block-device discovery completed and root has
  not yet been mounted;
- `initramfs-root-mounted.log`: mkinitcpio returned from the root mount;
- `initramfs-before-switch-root.log`: mkinitcpio is about to start systemd; and
- `initramfs-emergency.log`: root discovery, filesystem checking, or mounting
  entered an emergency path.

Each file includes the kernel command line, resolved root settings, `blkid`,
device links, mounts, loaded modules, DRM sysfs entries, `dmesg`, and the
mkinitcpio trace available at that stage. The hook creates only the
`archneo-diagnostics` directory on the FAT filesystem; it does not change ABL,
the `ROCKNIX` label, `/KERNEL`, or any internal-storage partition.

The presence of `/var/lib/archneo/userspace-reached` proves that the real root
was mounted read-write and the capture service started. Each boot receives a
directory named with its kernel boot ID. The latest available snapshot should
contain the most complete DRM/DSI failure evidence.

If the FAT stage directory is also absent, Linux did not reach the custom
mkinitcpio hook or could not enumerate and mount the removable FAT partition.
The remaining observation path is the configured `ttyMSM0` UART.
