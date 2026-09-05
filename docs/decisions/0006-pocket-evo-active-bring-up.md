# ADR 0006: Make Pocket EVO the active bring-up device

- Status: accepted
- Date: 2026-09-05

## Context

Archneo began with remote Pocket S 2K testing. The shared SM8550 kernel,
official Arch Linux ARM rootfs, ROCKNIX firmware, ABL-compatible image layout,
and console-first userspace all became reproducible in CI. Pocket S 2K tests
did not establish that Linux reached userspace, however, and physical access
to that device was unavailable.

A Pocket EVO is now locally available. Its pinned ROCKNIX device tree shares
`qcs8550-ayaneo-pocket-common.dtsi` with Pocket S 2K but supplies an EVO board
identity, a single-DSI Chipone ICNA3512 panel, and a FocalTech FT5426
touchscreen. Local access makes controlled boot iterations and immediate media
inspection practical.

## Decision

Pocket EVO (`ayaneo-pocket-evo`) becomes the default and active Archneo
bring-up profile. Pocket S 2K remains a buildable, separate profile; its work
is deferred rather than removed.

The EVO image retains the established SM8550 boot envelope:

1. use the already-installed ROCKNIX-ABL without updating or replacing it;
2. keep the first GPT partition named `system`, starting at sector `32768`,
   formatted FAT32 at 2048 MiB, labelled `ROCKNIX`, with attribute bit 2;
3. package Android boot image v0 as `/KERNEL` with `/KERNEL.md5`;
4. append the complete pinned ROCKNIX SM8550 DTB set so ABL can select the
   EVO entry; and
5. mount the ext4 root directly by its EVO-specific GPT `PARTUUID`.

Each device profile owns its selected DTB and deterministic filesystem/GPT
identities. Common platform constants no longer carry Pocket S 2K UUIDs.

## Consequences

- The default workflow produces a Pocket EVO image and names its artifact
  accordingly.
- S 2K and EVO media cannot accidentally share Archneo filesystem or GPT
  identities.
- Existing S 2K observations remain historical evidence, not EVO results.
- A successful EVO TTY is still bring-up evidence; support requires the full
  independently recorded hardware matrix.
