# Writing an Archneo removable image

These instructions write an Archneo image to a removable microSD card. They do
not install, update, or replace ROCKNIX-ABL on the handheld.

> [!WARNING]
> Writing a disk image destroys the existing partition table and data on the
> selected target. Identify the removable card by its capacity, model, and
> transport. Never select the computer's system disk or a numbered partition.

The current image is 33,810 MiB before compression, so a nominal 32 GB card is
too small. Use a card of at least 64 GB. The initial `/home` filesystem is a
1 GiB seed and expands into the remaining card capacity on first boot.

## Unpack and verify the artifact

GitHub Actions downloads an outer artifact ZIP. Extract that ZIP once. The
extracted directory contains the actual compressed disk image and its checksum:

```text
Archneo-ayaneo-pocket-evo-early-boot-diagnostic.img.gz
Archneo-ayaneo-pocket-evo-early-boot-diagnostic.img.gz.sha256
```

From a terminal in that extracted directory, verify the image before writing:

```sh
sha256sum --check Archneo-ayaneo-pocket-evo-early-boot-diagnostic.img.gz.sha256
```

Continue only if the result is `OK`. Do not extract the inner `.img.gz` when
using balenaEtcher; Etcher can decompress it while writing.

## Recommended: balenaEtcher

1. Open balenaEtcher and choose **Flash from file**.
2. Select `Archneo-ayaneo-pocket-evo-early-boot-diagnostic.img.gz`, not the
   outer GitHub ZIP.
3. Choose the removable microSD card as the target. Confirm its capacity and
   model before continuing.
4. Select **Flash** and allow Etcher's validation phase to finish.
5. Safely eject the card. Desktop automounting after validation is harmless;
   eject every mounted partition before physically removing it.

The image is a complete disk image. Do not copy it into the `ROCKNIX`
filesystem and do not create or format partitions manually.

## Command-line alternative

First identify the whole removable device:

```sh
lsblk --paths --output NAME,SIZE,MODEL,TRAN,TYPE,MOUNTPOINTS
```

Unmount each mounted partition using the desktop or `udisksctl`. In the command
below, replace `/dev/sdX` with the verified whole-card device. A target such as
`/dev/sdX1` is a partition and is wrong.

```sh
gzip --decompress --stdout Archneo-ayaneo-pocket-evo-early-boot-diagnostic.img.gz |
  sudo dd of=/dev/sdX bs=16M iflag=fullblock status=progress conv=fsync
sync
```

Remove and reinsert the card, then inspect it without changing it:

```sh
lsblk --fs /dev/sdX
```

The expected partitions are a 2 GiB FAT32 `ROCKNIX`, a 30 GiB ext4
`ARCHNEO_ROOT`, and an approximately 1 GiB ext4 `ARCHNEO_HOME` before its first
successful boot-time expansion.

## First Pocket EVO boot

Insert the safely ejected card into Pocket EVO and select **Pocket EVO** in
ROCKNIX-ABL. The intended first visible milestone is the Archneo `tty1` setup,
which asks separately for `root` and `deck` passwords. There are no preset
passwords. Let the first boot finish because `/home` expansion and persistent
diagnostic capture run automatically.

If the diagnostic image remains black, leave it running for at least two
minutes before forcing it off. Return the card to an Ubuntu workstation, mount
`ROCKNIX`, and inspect the pre-systemd evidence first:

```sh
boot="/media/$USER/ROCKNIX"
find "$boot/archneo-diagnostics" -maxdepth 3 -type f -printf '%P  %s bytes\n'
```

Preserve the entire `archneo-diagnostics` directory before another test. Its
absence means Linux did not reach the custom initramfs hook or the hook could
not enumerate and mount the FAT filesystem.
