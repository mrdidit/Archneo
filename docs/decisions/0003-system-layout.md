# ADR 0003: Use ext4, filesystem UUIDs, and separate root and home

- Status: accepted
- Date: 2026-08-27

## Context

Archneo needs a conservative first removable image for ROCKNIX-ABL while
providing a conventional writable Arch system. Removable-media device names are
not stable. The initial account set must not inherit Arch Linux ARM's published
generic-image credentials.

## Decision

The Pocket S 2K removable image uses GPT with:

1. a 2048 MiB FAT32 `/boot`, beginning at sector 32768 and labelled exactly
   `ROCKNIX`;
2. a 30 GiB ext4 `/`; and
3. an ext4 `/home` seed that expands to all remaining media on first boot.

The image uses no Btrfs. The kernel command line and `/etc/fstab` identify
filesystems by filesystem UUID, never by `/dev` path, by-path name, or
PARTUUID. Expansion preserves the home filesystem UUID.

The only interactive accounts are `root` and `deck`. `deck` is UID/GID 1000,
uses Bash, belongs to `wheel`, and receives password-protected sudo access.
The generic `alarm` account is removed. Both retained accounts remain locked
until the local first-boot credential flow successfully establishes passwords;
SSH is disabled initially.

## Consequences

- The final Android boot-image ramdisk must contain a real initramfs capable of
  resolving `root=UUID=…`; the compile-smoke dummy ramdisk is not bootable.
- `/home` can grow independently while `/` remains predictably sized.
- A cloned removable image has deterministic filesystem identities. A future
  internal installer must generate new per-install UUIDs to prevent collisions
  and must rebuild the payload command line accordingly.
- Resizing root later is possible with normal partition and ext4 tools, but it
  is not an automatic operation and can require moving the following home
  partition. Rebuilding an image with a new root size is safer before release.
