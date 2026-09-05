# Building Archneo

The repository prepares the ROCKNIX-derived kernel and complete SM8550 device
tree set, constructs an Arch Linux ARM rootfs, and assembles a direct-root,
ROCKNIX-ABL-compatible removable-media image.

## Host requirements

The scripts target a Linux x86-64 build host. On an Ubuntu or Debian host, the
kernel stage requires packages equivalent to:

```text
bc bison build-essential cpio curl dwarves flex gcc-aarch64-linux-gnu git kmod
libelf-dev libncurses-dev libssl-dev patch python3 xz-utils
```

No container or root privileges are required for source preparation or kernel
compilation. Rootfs and image assembly additionally require:

```text
dosfstools e2fsprogs fdisk gdisk gnupg libarchive-tools parted
qemu-user-static rsync
```

Rootfs extraction, aarch64 chroot configuration, loop devices, filesystem
creation, and mounting require root. Kernel trees
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

Cross-build the Pocket EVO kernel, every pinned ROCKNIX SM8550 DTB, and common
modules, then create the Android boot-image-v0 direct-root payload:

```sh
make kernel
```

The primary output is:

```text
out/ayaneo-pocket-evo/KERNEL
```

This payload contains a valid empty `newc` ramdisk, the complete appended DTB
set, and `root=PARTUUID=…`. It becomes bootable when paired with the matching
root filesystem in the complete image. `KERNEL.md5` is generated for ABL and
`KERNEL.sha256` remains Archneo's provenance checksum.

Build the complete removable image after `make kernel`:

```sh
sudo make image
```

After a direct-root test produces no userspace evidence, build the separately
named early-boot diagnostic image:

```sh
sudo make diagnostic-image
```

That variant retains the EVO root `PARTUUID` and complete appended DTB set,
but links a generated mkinitcpio archive into Linux and writes pre-systemd
stages below `/archneo-diagnostics` on the FAT filesystem. Its image is:

```text
out/ayaneo-pocket-evo/Archneo-ayaneo-pocket-evo-early-boot-diagnostic.img.gz
```

The image stage:

1. downloads the generic Arch Linux ARM rootfs and verifies its detached
   signature against a checksum-pinned official keyring;
2. installs the custom modules, Arch Linux ARM's version-recorded
   `linux-firmware` package, checksum-pinned ROCKNIX SM8550 firmware,
   NetworkManager, and `wpa_supplicant`;
3. updates the rootfs from the official Arch Linux ARM repositories under
   qemu, removes `alarm`, creates locked `root` and `deck` accounts, and sets
   `multi-user.target` as the default;
4. enables NetworkManager and the `tty1` first-boot password setup while
   disabling systemd-networkd and SSH; and
5. creates and verifies the FAT32/ext4/ext4 disk image with GPT boot name
   `system`, FAT label `ROCKNIX`, `/KERNEL`, and both kernel checksums.

The ordinary direct-root output is:

```text
out/ayaneo-pocket-evo/Archneo-ayaneo-pocket-evo.img.gz
```

See [writing an Archneo removable image](writing-removable-media.md) for the
minimum card size, checksum verification, balenaEtcher procedure, and guarded
command-line alternative.

Archneo does not overlay `/etc/pacman.conf`. The configuration and mirror list
from the signature-verified Arch Linux ARM rootfs remain installed, including
the normal `[core]`, `[extra]`, `[alarm]`, and `[aur]` repositories. Pocknix's
frozen package repository is not copied or referenced.

The compressed image, SHA-256 file, partition-table JSON, and build manifests
are retained in `out`. The large sparse raw image remains in the persistent
build directory rather than `/tmp`.

Pocket EVO is the active default profile. Pocket S 2K remains available as an
explicit override; producing either artifact does not constitute hardware
support:

```sh
ARCHNEO_DEVICE=ayaneo-pocket-s-2k make kernel
sudo ARCHNEO_DEVICE=ayaneo-pocket-s-2k make image
```

`CROSS_COMPILE`, `JOBS`, and `ARCHNEO_BUILD_DIR` may be overridden. Their
defaults are `aarch64-linux-gnu-`, the host's reported CPU count, and the
persistent cache path described above. Any overridden kernel build path must not
contain spaces or colons.

## Continuous build

The `Build Pocket EVO diagnostic image` GitHub Actions workflow runs verification,
`make kernel`, and the privileged early-boot diagnostic image path on relevant
changes. It
retains the compressed image and its manifests for 14 days. A successful
workflow proves build and filesystem verification only; it is not hardware
boot evidence or a supported release.

The first kernel-only milestone passed in GitHub Actions run
[`33063572182`](https://github.com/mrdidit/Archneo/actions/runs/33063572182).
Its `KERNEL` SHA-256 was
`cecdb51388817285e8391b6e3096716a2422eb096b3898c891639bf6d756d07a`;
the uploaded workflow artifact digest was
`df44dd26ea9f35b4662d0c8cdfeb07b9b1506c722f8ef3ad32510eb49aa03f72`.
Hardware remained untested.

The first five full-image attempts, GitHub Actions runs
[`33071305455`](https://github.com/mrdidit/Archneo/actions/runs/33071305455) and
[`33074171748`](https://github.com/mrdidit/Archneo/actions/runs/33074171748),
then [`33079249905`](https://github.com/mrdidit/Archneo/actions/runs/33079249905),
and [`33083220681`](https://github.com/mrdidit/Archneo/actions/runs/33083220681),
then [`33086444548`](https://github.com/mrdidit/Archneo/actions/runs/33086444548),
all verified both source archives and the Arch Linux ARM signature. No image was
produced. The first two failed the initial aarch64 execution. Inspection and a
minimal reproduction showed that syncing the kernel's top-level `lib/modules`
overlay replaced Arch's `/lib -> usr/lib` compatibility symlink with a
directory, making the interpreter unreachable.

Module installation now copies only the contents below `lib/modules` into
`/usr/lib/modules`. Before QEMU starts, the builder requires `/lib -> usr/lib`,
`/bin -> usr/bin`, and an executable aarch64 interpreter. It then runs an
aarch64 `/bin/true` preflight before Pacman. The third run passed all of those
checks and entered Pacman, where Pacman 7 rejected its downloader because
Landlock is unavailable through qemu-user. The emulated system-update command
now uses Pacman's documented `--disable-sandbox` option; the installed
`pacman.conf` remains unchanged. The fourth run passed that boundary, resolved
the complete package transaction, then Pacman's `CheckSpace` safety check could
not map `/var/cache/pacman/pkg` to a mount point because the chroot root was a
plain host directory. The builder now makes the rootfs a private self-bind
mount and verifies the cache mount/free-space view before Pacman. The
fifth run completed the package transaction, account setup, and service
enablement, then stopped when the builder passed the Bash-based `mkinitcpio`
script directly to QEMU as an ELF program. The log also showed that archival
overlay copies had propagated runner UID 1001 onto system directories, causing
systemd's safety checks to reject paths during package hooks.

Build-supplied modules, policy files, and firmware are now explicitly owned by
root, and `/`, `/etc`, and `/usr` ownership is validated before entering the
chroot. `mkinitcpio` now runs through guest Bash. Files created for `deck` later
retain UID/GID 1000. The replacement, GitHub Actions run
[`33089290964`](https://github.com/mrdidit/Archneo/actions/runs/33089290964),
completed successfully at commit
`787ef0d8717b2248c9039f103a60e40144eff779`. Its uploaded artifact digest was
`459e0e0b0760419a1e259e8923102db3d923c4c963e5195426319dc0c1fcb955`.

The first hardware test wrote that image to removable media and confirmed the
expected partition labels and UUIDs. ABL appeared to select `/KERNEL`, but the
Pocket S 2K remained on a black screen and required forced power-off. The root
filesystem then contained neither systemd journal files nor Archneo first-boot
markers. That image placed the functional initramfs in the Android boot-image
ramdisk field, whereas public ROCKNIX builds the real initramfs into Linux and
uses the literal `dummy` externally. The ADR 0004 follow-up tested that
built-in arrangement.

The replacement diagnostic image from GitHub Actions run
[`33193171460`](https://github.com/mrdidit/Archneo/actions/runs/33193171460),
commit `ce5478e7e1519afe1135210205ce0aa23340b42f`, was then tested. Its FAT
manifest confirmed `initramfs_delivery=kernel-built-in` and the expected
`drm.debug` display logging command line, and `KERNEL.sha256` verified the
payload as
`551c256fc8a83f6547bd8a77b7ed8dfcbde399d46267ed8388774860ab385d82`.
The display remained black, and the ext4 root again contained neither a
systemd journal nor any file below `/var/lib/archneo`. A later diagnostic
branch moved capture into mkinitcpio. After a collaborator reported that
Pocknix's multi-DTB, initramfs-free SM8550 image boots on Pocket S 2K, the
active test changed to the direct-root parity profile in ADR 0005. Archneo does
not use Pocknix's userspace, package repository, or Btrfs layout.

## Source and patch policy

[`config/sources.env`](../config/sources.env) is the source lock. The preparation
script applies patches in the same relevant order selected by the pinned
ROCKNIX build:

1. `projects/ROCKNIX/packages/linux/patches/mainline/*.patch`
2. `projects/ROCKNIX/packages/linux/patches/7.2/*.patch`
3. `projects/ROCKNIX/devices/SM8550/patches/linux/*.patch`

Files ending in `.disabled` are deliberately excluded. The entire SM8550 DTS
overlay is then copied into the kernel tree. Every `qcs8550-*.dts` supplied by
that pinned overlay is built and its DTB is appended in deterministic filename
order; the manifest separately records Pocket EVO as the selected Archneo
device profile. Per-device DTB selection and stable media identities live in
[`config/devices`](../config/devices).

The active bring-up configuration clears `CONFIG_INITRAMFS_SOURCE`, sets the
hostname/local version, and pins devtmpfs, Qualcomm MMC/SDHCI, and ext4 as
built-ins. Linux resolves the fixed root GPT UUID and mounts ext4 directly.
The Android boot-image ramdisk is a valid empty `newc` archive. The baseline
kernel deltas are recorded in
[`config/kernel/archneo-sm8550.fragment`](../config/kernel/archneo-sm8550.fragment).

## Reproducibility boundary

The Linux, ROCKNIX extra-firmware, and `mkbootimg` archives are checksum-pinned.
ROCKNIX sources are commit-pinned. The generic Arch Linux ARM rootfs URL is a moving
`latest` artifact: every downloaded copy is signature-verified and its exact
SHA-256 is recorded, but CI can receive a newer valid snapshot. A release must
pin or archive that verified snapshot before claiming byte-for-byte
reproducibility. The full system upgrade also follows Arch Linux ARM's live
package repositories and is recorded in the image package manifest.

Arch Linux ARM's official rootfs host redirects downloads to HTTP mirrors and
does not present a certificate valid for `os.archlinuxarm.org`. The build does
not treat that transport as trusted: it accepts only the exact configured
official rootfs/signature paths, obtains the official keyring from a pinned
HTTPS URL with a pinned SHA-256, and rejects the rootfs unless its detached
signature validates to the configured signing fingerprint.

## Firmware provenance boundary

Upstream firmware is installed through Arch Linux ARM's `linux-firmware`
package family, whose exact installed versions are captured in
`/usr/share/archneo/packages.txt`. SM8550 device-specific files come from the
commit and archive checksum in `config/sources.env`. At the pinned ROCKNIX
revision, its
[`extra-firmware` package metadata](https://github.com/ROCKNIX/distribution/blob/13e18947d2d41b17015f5df18405adefc4dfb2f5/projects/ROCKNIX/packages/linux-firmware/extra-firmware/package.mk)
classifies those blobs as `proprietary` and copies the `SM8550` subtree into
the firmware directory.

The source repository does not provide a general licence file covering that
SM8550 subtree. Archneo therefore records its provenance but does not infer
redistribution permission from public availability. Full-image artifacts are
bring-up builds, not licence-cleared releases; public release remains blocked
until every redistributed blob has an adequate licence or a documented lawful
distribution basis.
