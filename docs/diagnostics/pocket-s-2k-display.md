# Pocket S 2K black-screen diagnostic image

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
sudo ls -la "$root/var/lib/archneo"
sudo find "$root/var/lib/archneo/diagnostics" -maxdepth 2 -type f -ls
sudo journalctl --directory="$root/var/log/journal" --list-boots
sudo journalctl --directory="$root/var/log/journal" --boot=0 --dmesg --no-pager
```

The presence of `/var/lib/archneo/userspace-reached` proves that the real root
was mounted read-write and the capture service started. Each boot receives a
directory named with its kernel boot ID. The latest available snapshot should
contain the most complete DRM/DSI failure evidence.

If the marker and persistent journal are both absent, the evidence does not
support treating this as a display-only failure. Diagnosis must move earlier,
through the configured `ttyMSM0` UART or a later initramfs-level capture
mechanism.
