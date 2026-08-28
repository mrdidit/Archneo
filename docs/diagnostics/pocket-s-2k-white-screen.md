# Pocket S 2K white-screen diagnostic image

## Purpose

The second reported Pocket S 2K observation changed from a black screen to a
white screen with a vibration during startup. The exact image identity and
post-test filesystem evidence remain to be recorded. A white panel establishes
neither Linux entry nor successful display initialization: ABL may have left
the panel powered without valid DSI scanout, and the vibration may originate
before Linux.

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
3. Record when vibration and each visible display change occurs.
4. Leave the device powered for at least 75 seconds, even if the panel remains
   white, then force power-off only if normal shutdown remains unavailable.
5. Return the card to the build workstation and mount `ARCHNEO_ROOT` read-only
   if practical.

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

If neither the marker nor a persistent journal exists, the failure remains
before this systemd service and must be diagnosed through the configured
`ttyMSM0` UART or a later initramfs-level capture mechanism.
