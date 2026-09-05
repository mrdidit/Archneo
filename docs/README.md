# Archneo documentation

Archneo documentation is developed alongside the implementation. A device is
not considered supported merely because it reaches a graphical interface.
Build provenance, installation, removable-media rollback, hardware validation,
and known limitations are part of the deliverable.

## Project documents

- [Bring-up roadmap](roadmap.md)
- [Building Archneo](building.md)
- [Pocket S 2K black-screen diagnostics](diagnostics/pocket-s-2k-display.md)
- [ROCKNIX-ABL boot contract](architecture/boot-contract.md)
- [Planned internal-storage installer](architecture/internal-installer.md)
- [AYANEO Pocket S 2K](devices/ayaneo-pocket-s-2k.md)
- [AYANEO Pocket EVO](devices/ayaneo-pocket-evo.md)
- [ADR 0001: bring up the Pocket S 2K first](decisions/0001-pocket-s-2k-first.md)
- [ADR 0002: treat ROCKNIX-ABL as an external interface](decisions/0002-abl-is-an-external-interface.md)
- [ADR 0003: ext4, UUID, account, and partition layout](decisions/0003-system-layout.md)
- [ADR 0004: keep the functional initramfs inside the kernel](decisions/0004-built-in-initramfs.md)
- [ADR 0005: match the proven SM8550 ABL envelope and boot ext4 directly](decisions/0005-direct-root-abl-parity.md)
- [ADR 0006: make Pocket EVO the active bring-up device](decisions/0006-pocket-evo-active-bring-up.md)

## Documentation rules

Every device-affecting change must record:

- the device and hardware revision on which it was tested;
- exact source revisions, patches, configuration, and firmware provenance;
- the build and test commands used;
- expected and observed results, including regressions;
- rollback implications and any persistent changes made to the device; and
- relevant licences and attribution.

Unverified procedures must be labelled as such. Initial Archneo procedures
operate on removable media. Internal-storage installation is a later,
separately gated workflow and cannot be reached from the image builder. ABL
installation and Android backup/restoration are external prerequisites, not
Archneo procedures.
