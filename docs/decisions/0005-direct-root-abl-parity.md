# ADR 0005: Match the proven SM8550 ABL envelope and boot ext4 directly

- Status: accepted
- Date: 2026-08-28

## Context

Two Archneo Pocket S 2K images used a single appended device tree and depended
on an Archneo initramfs, first in the Android ramdisk and then built into Linux.
Neither test produced a systemd journal or a userspace marker.

Pocknix independently packages its SM8550 kernel as an Android boot image with
the complete ROCKNIX SM8550 DTB set appended. It uses a valid empty Android
ramdisk and lets Linux mount the root filesystem directly. Its removable boot
filesystem is FAT32-labelled `ROCKNIX`, lives in a GPT partition named
`system`, and carries both `KERNEL` and `KERNEL.md5`.

On 2026-08-28, an Archneo collaborator reported that this Pocknix SM8550 image
boots on a Pocket S 2K after selecting that device in ROCKNIX-ABL. Audio did
not work. This is valuable hardware evidence for the boot envelope, but it is
not an Archneo boot result and the exact Pocknix image/build identity remains
to be recorded.

The Pocknix userspace and package policy are not an Archneo input. In
particular, Archneo will not adopt Pocknix's frozen package repository,
Btrfs layout, board fallback, or RP6 audio/session configuration.

Reviewed Pocknix revision:
`9a7a6a160ee85d066c1a9c8a1ae901bd811c4c0c`.

- [SM8550 ABL and direct-root profile](https://github.com/shuuri-labs/pocknix-os/blob/9a7a6a160ee85d066c1a9c8a1ae901bd811c4c0c/devices/sm8550/profile.conf)
- [multi-DTB Android boot-image assembly](https://github.com/shuuri-labs/pocknix-os/blob/9a7a6a160ee85d066c1a9c8a1ae901bd811c4c0c/scripts/build-kernel.sh)
- [removable GPT and `KERNEL.md5` construction](https://github.com/shuuri-labs/pocknix-os/blob/9a7a6a160ee85d066c1a9c8a1ae901bd811c4c0c/scripts/build-sd-image.sh)
- [Pocket S 2K DTS](https://github.com/shuuri-labs/pocknix-os/blob/9a7a6a160ee85d066c1a9c8a1ae901bd811c4c0c/kernel/sm8550/dts/qcom/qcs8550-ayaneo-pockets2k.dts)
- [unsupported-model RP6 fallback](https://github.com/shuuri-labs/pocknix-os/blob/9a7a6a160ee85d066c1a9c8a1ae901bd811c4c0c/devices/sm8550/packages/pocknix-bsp-sm8550/device.conf)

## Decision

The next Archneo Pocket S 2K image will:

1. retain the installed ROCKNIX-ABL without modifying it;
2. retain the 16 MiB start, 2048 MiB size, Microsoft Basic Data type,
   legacy-boot attribute, and FAT32 label `ROCKNIX` for partition 1;
3. name that removable GPT partition `system`;
4. install `/KERNEL`, `/KERNEL.md5`, and Archneo's additional
   `/KERNEL.sha256` provenance checksum;
5. append every device DTB supplied by the pinned ROCKNIX SM8550 DTS set in
   deterministic filename order;
6. place a valid empty `newc` archive in the Android ramdisk;
7. keep `CONFIG_INITRAMFS_SOURCE` empty and mount the ext4 root directly with
   `root=PARTUUID=… rootfstype=ext4 rw rootwait`; and
8. force `multi-user.target` so the first visible userspace is the local TTY
   credential setup, not a graphical session.

The root `PARTUUID` exception is confined to the kernel's pre-userspace root
lookup. `/etc/fstab` continues to identify `/boot`, `/`, and `/home` by
filesystem UUID. There are no `/dev` paths in either interface.

The rootfs retains Arch Linux ARM's official `pacman.conf` and mirror list.
It installs NetworkManager and `wpa_supplicant` from those repositories,
disables the conflicting systemd-networkd units, and starts NetworkManager
without a preconfigured wireless network.

Both `root` and `deck` are locked in the image. A service attached to `tty1`
runs before the normal getty and requires a password to be set independently
for each account. `deck` retains password-protected `wheel` sudo access.

## Consequences

- The next test removes initramfs construction and UUID resolution as early
  boot variables while retaining ext4 and stable identifiers.
- The complete SM8550 DTB set deliberately follows the boot layout already
  observed working on Pocket S 2K; userspace support remains device-specific.
- A successful TTY/password prompt proves ABL handoff, DTB selection, direct
  root mounting, and systemd startup before graphical work begins.
- A failure before systemd cannot produce the former mkinitcpio FAT markers;
  serial capture remains the only log source for a failure that early.
- Pocknix's reported Pocket S 2K audio failure is not inherited configuration.
  Archneo must later provide and test an ALSA UCM profile for the DTS sound-card
  model `SM8550-APS`.
- ADR 0004 remains the record of the previous built-in-initramfs experiment,
  but it no longer describes the active bring-up image.
