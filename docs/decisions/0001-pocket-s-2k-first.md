# ADR 0001: Bring up the Pocket S 2K first

- Status: superseded by [ADR 0006](0006-pocket-evo-active-bring-up.md)
- Date: 2026-08-27

## Context

Archneo's first two targets are the AYANEO Pocket S 2K and AYANEO Pocket EVO.
Both use SM8550 and share a substantial ROCKNIX device-tree base. The Pocket S
2K has the more involved display path: its device tree describes a dual-DSI
panel, external panel regulators, a separate backlight controller, and a
Goodix touchscreen.

Starting with Pocket EVO would likely provide a simpler initial display
bring-up. The project has intentionally chosen to resolve the Pocket S 2K path
first instead.

## Decision

AYANEO Pocket S 2K is the first Archneo bring-up device. AYANEO Pocket EVO is
the second device. Shared work will be implemented at the SM8550 platform
level, with explicitly separated device profiles and validation results.

The name `Pocket S 2K` will always be used in human-facing documentation. The
identifier `ayaneo-pocket-s-2k` will be used in code and paths.

## Consequences

- Initial display debugging may take longer.
- The shared platform design must not encode Pocket S 2K assumptions.
- Pocket EVO support can follow once the common boot and userspace layers are
  proven.
- Test results for one device cannot be used as evidence for the other.

## Out of scope

AYANEO Pocket S2 is a different SM8650 device. It is not included in this
decision or the initial Archneo milestone.
