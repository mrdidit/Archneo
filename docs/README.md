# Archneo documentation

Archneo documentation is developed alongside the implementation. A device is
not considered supported merely because it reaches a graphical interface.
Build provenance, recovery, installation, hardware validation, and known
limitations are part of the deliverable.

## Project documents

- [Bring-up roadmap](roadmap.md)
- [AYANEO Pocket S 2K](devices/ayaneo-pocket-s-2k.md)
- [AYANEO Pocket EVO](devices/ayaneo-pocket-evo.md)
- [ADR 0001: bring up the Pocket S 2K first](decisions/0001-pocket-s-2k-first.md)

## Documentation rules

Every device-affecting change must record:

- the device and hardware revision on which it was tested;
- exact source revisions, patches, configuration, and firmware provenance;
- the build and test commands used;
- expected and observed results, including regressions;
- recovery implications and any persistent changes made to the device; and
- relevant licences and attribution.

Unverified procedures must be labelled as such. Destructive or persistent
steps must not be published as normal installation instructions until their
recovery procedure has been tested.
