# Building Archneo

The repository currently prepares and builds the first boot component: a
ROCKNIX-ABL-compatible `KERNEL` payload for the AYANEO Pocket S 2K. Rootfs and
complete disk-image construction are the next implementation stage.

## Host requirements

The scripts target a Linux x86-64 build host. On an Ubuntu or Debian host, the
kernel stage requires packages equivalent to:

```text
bc bison build-essential curl dwarves flex gcc-aarch64-linux-gnu git kmod
libelf-dev libncurses-dev libssl-dev patch python3 xz-utils
```

No container or root privileges are required for source preparation or kernel
compilation. Image assembly will add FAT/ext4 tooling later. Kernel trees
default to the persistent `${XDG_CACHE_HOME:-~/.cache}/archneo/build` because
the Linux build system rejects source paths containing spaces. They are not
placed in `/tmp`, so multi-day work survives normal temporary-file cleanup.
Verified downloads remain in the repository's `.cache` and published artifacts
go to `out`.

## Commands

Validate repository metadata and shell syntax:

```sh
make verify
```

Fetch the pinned ROCKNIX revision and prepare a Linux tree with the selected
ROCKNIX patch stack, SM8550 configuration, and DT sources:

```sh
make prepare-kernel
```

Cross-build the Pocket S 2K kernel, DTB, and modules, then create the Android
boot-image-v0 payload:

```sh
make kernel
```

The primary output is:

```text
out/ayaneo-pocket-s-2k/KERNEL
```

Its directory also contains `KERNEL.sha256`, a build manifest, the intermediate
kernel/DTB stream, and a modules rootfs overlay. Build and download directories
are intentionally untracked.

Pocket EVO is recognized by the build script for later development, but it is
not the default and does not yet constitute a supported artifact:

```sh
ARCHNEO_DEVICE=ayaneo-pocket-evo make kernel
```

`CROSS_COMPILE`, `JOBS`, and `ARCHNEO_BUILD_DIR` may be overridden. Their
defaults are `aarch64-linux-gnu-`, the host's reported CPU count, and the
persistent cache path described above. Any overridden kernel build path must not
contain spaces or colons.

## Continuous build

The `Build Pocket S 2K kernel` GitHub Actions workflow runs the same verification
and `make kernel` path on relevant changes to `main`, on pull requests, and on
manual dispatch. It installs the documented compiler dependencies on the
runner and retains the payload directory as a workflow artifact for 14 days.
The workflow is a compile/package check; an uploaded artifact is not a hardware
validation result or a release image.

## Source and patch policy

[`config/sources.env`](../config/sources.env) is the source lock. The preparation
script applies patches in the same relevant order selected by the pinned
ROCKNIX build:

1. `projects/ROCKNIX/packages/linux/patches/mainline/*.patch`
2. `projects/ROCKNIX/packages/linux/patches/7.2/*.patch`
3. `projects/ROCKNIX/devices/SM8550/patches/linux/*.patch`

Files ending in `.disabled` are deliberately excluded. The entire SM8550 DTS
overlay is then copied into the kernel tree, while the packaged payload uses
only the selected device DTB.

ROCKNIX normally embeds its appliance initramfs. Archneo clears
`CONFIG_INITRAMFS_SOURCE`, sets its hostname/local version, and mounts an ext4
Arch root directly. Those deltas are recorded in
[`config/kernel/archneo-sm8550.fragment`](../config/kernel/archneo-sm8550.fragment).

## Reproducibility boundary

The Linux and `mkbootimg` archives are checksum-pinned. The ROCKNIX source is
commit-pinned. The generic Arch Linux ARM rootfs URL is currently a moving
`latest` artifact; it will be signature-verified and snapshotted before
Archneo publishes a release. Until then, the project must not describe a full
image as reproducible.
