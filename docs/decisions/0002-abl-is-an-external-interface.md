# ADR 0002: Treat ROCKNIX-ABL as an external interface

- Status: accepted
- Date: 2026-08-27

## Context

Archneo must boot through ROCKNIX-ABL on its initial SM8550 devices. The public
ROCKNIX distribution repository shows how its removable images are packaged,
and the public ABL repository publishes signed binaries. The loader source used
by the ABL release workflow is in the non-public `ROCKNIX/LinuxLoader`
repository, so its discovery logic cannot be audited or reproduced here.

The initial devices already have a working ROCKNIX-ABL installation. Android
backup, restoration, and bootloader installation are not part of this project.

## Decision

Archneo treats an already-installed, working ROCKNIX-ABL as a platform
prerequisite. The project implements the observable removable-media interface
from the pinned public ROCKNIX build and labels untested loader assumptions as
such. The ABL-facing FAT filesystem retains the `ROCKNIX` label as a fixed
compatibility requirement; Archneo does not attempt to change the loader's
contract.

Initial bring-up artifacts write only removable media. They do not contain ABL
binaries or internal-storage installers.

## Consequences

- Archneo can progress without redistributing or reverse-engineering ABL.
- ABL installation and Android recovery are outside the build documentation.
- The media layout remains deliberately close to ROCKNIX, including its FAT
  label and boot parameters.
- Compatibility claims require testing against a named ABL release.
- Changes to ABL can require a new compatibility baseline even when Archneo's
  kernel and root filesystem are unchanged.
