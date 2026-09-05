# ADR 0009: Preserve ROCKNIX DTB overlay symbols

- Status: accepted and implemented
- Date: 2026-09-05

## Context

Review of the Thorch AYN Thor build exposed an omitted part of Archneo's pinned
ROCKNIX kernel recipe. ROCKNIX invokes its SM8550 kernel build with
`DTC_FLAGS=-@`. Thorch independently retains that flag and rejects appended
DTBs without a root `__symbols__` node before constructing its ABL payload.

Archneo copied the same ROCKNIX DTS sources but did not pass `DTC_FLAGS=-@` to
either its ordinary kernel build or its diagnostic relink. The resulting DTBs
could therefore omit the symbol table expected by the ROCKNIX overlay flow.
The previous card inspection verified DTB names and checksums, but did not
inspect this internal property.

This is a concrete mismatch with the public ROCKNIX build contract. Whether it
fully explains the Pocket EVO failure remains a hardware-test question.

## Decision

Both Archneo kernel build paths now pass `DTC_FLAGS=-@`. Packaging scans every
DTB in the appended SM8550 set and fails unless `__symbols__` is present. The
manifest records `dtb_symbols=required-present`.

This correction is included in the same next hardware artifact as the USB ACM
diagnostic console. It does not change the DTS source, appended DTB order,
device selection, partition layout, ABL installation, or Arch Linux ARM
userspace.

## Consequences

- Archneo again matches the pinned ROCKNIX compiler invocation rather than only
  matching its source tree and output filenames.
- CI will stop before image publication if a future kernel or build change
  strips overlay symbols from any packaged DTB.
- The next EVO attempt tests two explicitly recorded corrections: restored DTB
  symbols in the ABL payload and a diagnostic-only USB console.
- A successful boot will not establish which correction was decisive without a
  later controlled comparison, but retaining `-@` is required independently
  for ROCKNIX recipe parity.
