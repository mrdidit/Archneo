# ADR 0003: Use ext4, filesystem UUIDs, and separate root and home

- Status: accepted
- Date: 2026-08-27

## Context

Archneo needs a conservative first removable image for ROCKNIX-ABL while
providing a conventional writable Arch system. Removable-media device names are
not stable. The initial account set must not inherit Arch Linux ARM's published
generic-image credentials.

## Decision

Each SM8550 device-profile image uses GPT with:

1. a 2048 MiB FAT32 `/boot`, beginning at sector 32768 and labelled exactly
   `ROCKNIX`;
2. a 30 GiB ext4 `/`; and
3. an ext4 `/home` seed that expands to all remaining media on first boot.

The image uses no Btrfs. `/etc/fstab` identifies all three filesystems by
filesystem UUID, never by a `/dev` path or by-path name. Expansion preserves
the home filesystem UUID. The direct-root bring-up kernel uses the root GPT
`PARTUUID` because the kernel can resolve it before userspace starts; this
narrow exception is recorded in [ADR 0005](0005-direct-root-abl-parity.md).

The only interactive accounts are `root` and `deck`. `deck` is UID/GID 1000,
uses Bash, belongs to `wheel`, and receives password-protected sudo access.
The generic `alarm` account is removed. Both retained accounts remain locked
until the local first-boot credential flow successfully establishes passwords;
SSH is disabled initially. The image boots to `multi-user.target`, runs the
credential flow on `tty1` before its normal getty, and separately invokes
`passwd root` and `passwd deck`.

NetworkManager and `wpa_supplicant` come from the official Arch Linux ARM
repositories. NetworkManager is enabled without a preconfigured connection,
and systemd-networkd is disabled to avoid competing network managers.

## Consequences

- The direct-root bring-up image needs the Qualcomm MMC/SDHCI path and ext4
  built into Linux. A functional initramfs is not required for this profile.
- `/home` can grow independently while `/` remains predictably sized.
- Each device profile has distinct deterministic filesystem identities. A future
  internal installer must generate new per-install UUIDs to prevent collisions
  and must rebuild the payload command line accordingly.
- Resizing root later is possible with normal partition and ext4 tools, but it
  is not an automatic operation and can require moving the following home
  partition. Rebuilding an image with a new root size is safer before release.
