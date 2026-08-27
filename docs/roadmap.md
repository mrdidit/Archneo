# Bring-up roadmap

## Scope

The first Archneo platform is Qualcomm SM8550. The initial device order is:

1. AYANEO Pocket S 2K
2. AYANEO Pocket EVO

Both device profiles will share the SM8550 kernel, firmware, root filesystem,
image-building code, and ROCKNIX-ABL boot contract wherever the hardware
permits. Device-tree and hardware-specific configuration remain separate.

AYANEO Pocket S2 support is out of scope for this milestone. Despite its
similar name, it is an SM8650 device.

Current implementation phase: the Pocket S 2K kernel and dummy-ramdisk
compile-smoke payload pass CI. Full rootfs, real-initramfs, and removable-image
assembly are implemented and awaiting their first CI result, followed by the
first hardware boot.

## Phases

### 0. Establish bring-up prerequisites

- Record exact device variants and hardware revisions.
- Require an already-installed, working ROCKNIX-ABL and record its version.
- Retain a known-working ROCKNIX removable image as the boot-contract baseline.
- Keep all initial Archneo writes confined to removable media.
- Capture the partition layout, boot logs, device tree, loaded modules,
  firmware requests, and hardware inventory from a working system.

Installing ABL and backing up or restoring Android are outside Archneo's
scope.

### 1. Specify the boot contract

- Document how ROCKNIX-ABL discovers and loads the Linux payload.
- Document the required partition types, labels, filesystems, paths, and boot
  arguments.
- Determine how the correct device tree is selected.
- Define the kernel, initramfs, device-tree, and root-filesystem interfaces.

### 2. Create reproducible build inputs

- Pin Arch Linux ARM bootstrap inputs and verify their integrity.
- Pin the kernel source and ROCKNIX patch set.
- Track kernel configuration, device trees, modules, and firmware explicitly.
- Record licences and provenance for every redistributed component.

### 3. Boot the Pocket S 2K from removable media

- Boot without installing Archneo to internal storage.
- Reach a diagnostic console with persistent logs.
- Mount the intended Arch root filesystem.
- Verify clean shutdown and repeatable cold boots.

### 4. Validate Pocket S 2K hardware

- Display, backlight, touchscreen, and orientation
- Internal and removable storage
- USB host/device behaviour
- Gamepad, buttons, analogue controls, and rumble
- GPU acceleration and display stability
- Audio input/output
- Wi-Fi and Bluetooth
- Battery, charging, thermal sensors, and fan control
- Suspend or the documented alternative

### 5. Add the Pocket EVO profile

- Include and select the Pocket EVO device tree.
- Repeat the complete hardware test matrix.
- Verify that adding EVO support does not regress Pocket S 2K.

### 6. Produce installable artifacts

- Build versioned, checksummed removable-media images.
- Publish build manifests and release notes.
- Document removable-media installation, update, and rollback.
- Treat internal installation as a separate future project, not part of the
  initial milestone.

### 7. Add the separately gated internal installer

- Prompt independently for `/boot`, `/`, and `/home` sizes.
- Default to 2 GiB, 30 GiB, and all remaining capacity.
- Preview the exact target and partition map before an explicit destructive
  confirmation.
- Keep `/boot` FAT32 with label `ROCKNIX`; generate per-install filesystem
  UUIDs and update both `fstab` and the ABL payload.
- Never expose this path through the removable-image build command.

## Definition of supported

A device is supported only when the image is reproducible, removable-media
boot and rollback are tested, the hardware matrix is published, and known
limitations are recorded. A one-off successful boot is bring-up evidence, not
support status.
