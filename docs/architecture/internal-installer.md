# Planned internal-storage installer

Status: design only; no internal installer is currently shipped.

Internal installation is deliberately separate from removable-image building
and first-device bring-up. `make image` can only create an image file; it never
selects or writes a physical disk.

## Interactive sizing contract

The future installer will ask for all three filesystem sizes rather than
silently copying the removable-image geometry:

| Mount | Default | Validation |
| --- | --- | --- |
| `/boot` | 2 GiB | FAT32, label exactly `ROCKNIX`, conservative minimum 2 GiB |
| `/` | 30 GiB | ext4, explicit positive size with system headroom |
| `/home` | remaining capacity | ext4; accepts an explicit size or `remaining` |

Before writing, it must display the resolved physical device, capacity,
existing partition table, requested sizes, resulting free/unallocated space,
and exact destructive operations. It must then require the user to type the
full target device name and a second explicit confirmation. Invalid totals or
a target containing the running root filesystem are hard failures.

## Identity and ABL rules

The installer will generate fresh filesystem UUIDs for each installation,
write those UUIDs to the installed `/etc/fstab`, and rebuild the installed
`/KERNEL` command line with the new root UUID. It will not use `/dev` paths or
PARTUUIDs in persistent configuration. The FAT filesystem may receive a new
FAT UUID, but its label remains exactly `ROCKNIX` because that is part of the
unchanged ROCKNIX-ABL contract.

The installer will not install, update, or repair ABL and will not run as a
side effect of any build or update command. Implementation starts only after a
removable Archneo image boots repeatably on the active Pocket EVO target.
