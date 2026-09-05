# Bring-up roadmap

## Scope

The first Archneo platform is Qualcomm SM8550. The active device order is:

1. AYANEO Pocket EVO
2. AYANEO Pocket S 2K (deferred until local testing is practical)

Both device profiles will share the SM8550 kernel, firmware, root filesystem,
image-building code, and ROCKNIX-ABL boot contract wherever the hardware
permits. Device-tree and hardware-specific configuration remain separate.

AYANEO Pocket S2 support is out of scope for this milestone. Despite its
similar name, it is an SM8650 device.

Current implementation phase: the earlier Pocket S 2K kernel, rootfs,
initramfs, and complete removable image passed CI assembly before the active
boot profile was changed. Both external- and built-in-initramfs hardware images
remained on a black screen and left no systemd journal or userspace marker. A
collaborator then reported that Pocknix's multi-DTB, direct-root SM8550 image
boots on Pocket S 2K, with audio not working. Archneo now applies that low-level
ABL envelope to a separate Pocket EVO profile while retaining ext4, Archneo
userspace, and the official rolling Arch Linux ARM repositories. A Pocket EVO
is locally available, so the immediate target is its `tty1` password setup.

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
- Validate the `system` GPT name, `ROCKNIX` FAT label, `KERNEL.md5`, appended
  SM8550 DTB set, and direct-root `PARTUUID` together on Pocket EVO.

### 2. Create reproducible build inputs

- Pin Arch Linux ARM bootstrap inputs and verify their integrity.
- Pin the kernel source and ROCKNIX patch set.
- Track kernel configuration, device trees, modules, and firmware explicitly.
- Record licences and provenance for every redistributed component.

### 3. Boot the Pocket EVO from removable media

- Boot without installing Archneo to internal storage.
- Reach the `tty1` credential setup, set distinct `root` and `deck` passwords,
  and then reach the normal login prompt.
- Verify NetworkManager starts and can create a connection with `nmcli`.
- Reach a diagnostic console with persistent logs.
- Mount the intended Arch root filesystem.
- Verify clean shutdown and repeatable cold boots.

### 4. Validate Pocket EVO hardware

- Display, backlight, touchscreen, and orientation
- Internal and removable storage
- USB host/device behaviour
- Gamepad, buttons, analogue controls, and rumble
- GPU acceleration and display stability
- Audio input/output
- Wi-Fi and Bluetooth
- Battery, charging, thermal sensors, and fan control
- Suspend or the documented alternative

### 5. Resume Pocket S 2K bring-up

- Build the retained Pocket S 2K device profile.
- Repeat the complete hardware test matrix.
- Verify that shared EVO changes do not regress Pocket S 2K.

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
