# Archneo documentation

Archneo documentation is developed alongside the implementation. A device is
not considered supported merely because it reaches a graphical interface.
Build provenance, installation, removable-media rollback, hardware validation,
and known limitations are part of the deliverable.

## Project documents

- [Bring-up roadmap](roadmap.md)
- [Building Archneo](building.md)
- [ROCKNIX-ABL boot contract](architecture/boot-contract.md)
- [AYANEO Pocket S 2K](devices/ayaneo-pocket-s-2k.md)
- [AYANEO Pocket EVO](devices/ayaneo-pocket-evo.md)
- [ADR 0001: bring up the Pocket S 2K first](decisions/0001-pocket-s-2k-first.md)
- [ADR 0002: treat ROCKNIX-ABL as an external interface](decisions/0002-abl-is-an-external-interface.md)

## Documentation rules

Every device-affecting change must record:

- the device and hardware revision on which it was tested;
- exact source revisions, patches, configuration, and firmware provenance;
- the build and test commands used;
- expected and observed results, including regressions;
- rollback implications and any persistent changes made to the device; and
- relevant licences and attribution.

Unverified procedures must be labelled as such. Initial Archneo procedures
must operate on removable media and must not include internal-storage writes.
ABL installation and Android backup/restoration are external prerequisites,
not Archneo procedures.
