# Archneo

Archneo is an experimental Arch Linux ARM distribution for ARM gaming
handhelds. It aims to combine an Arch userspace with device support derived
from ROCKNIX and a ROCKNIX-ABL-compatible boot layout.

> [!WARNING]
> Archneo is at the research and bring-up stage. Complete Pocket S 2K image
> assembly passes CI, but Archneo has not yet reached a confirmed TTY on
> hardware. It does not install or modify ABL.

## Goals

- Build a minimal, reproducible Arch Linux ARM root filesystem.
- Reuse the appropriate upstream and ROCKNIX kernel device support.
- Package the kernel, device trees, modules, and firmware needed per device.
- Produce images that follow the ROCKNIX-ABL boot contract.
- Document build, installation, update, and hardware-validation procedures.

## Status

The initial platform is Qualcomm SM8550. Device bring-up will proceed in this
order:

1. AYANEO Pocket S 2K (`ayaneo-pocket-s-2k`)
2. AYANEO Pocket EVO (`ayaneo-pocket-evo`)

The similarly named AYANEO Pocket S2 is an SM8650 device and is not one of
these initial targets. Source preparation and the earlier single-DTB `KERNEL`
payload passed CI. Rootfs, firmware, and complete removable-image assembly also
passed CI before the active boot-profile change. A hardware test of the
corrected built-in-initramfs image still left the display black and produced no
systemd journal or userspace marker.

An external Pocknix SM8550 image has since been reported booting on Pocket S
2K when that model is selected in ROCKNIX-ABL, although its audio does not
work. The active Archneo test now copies only its proven low-level envelope:
the full pinned ROCKNIX SM8550 DTB set, `KERNEL.md5`, and direct ext4 root
mounting. Archneo retains its own ext4 layout, userspace, and the official
rolling Arch Linux ARM repositories; no Pocknix package configuration is used.

The image boots to `tty1` and asks independently for `root` and `deck`
passwords before starting the normal login prompt. `deck` has
password-protected sudo access. NetworkManager is installed and enabled, but
no wireless network is preconfigured and no graphical session is installed
for this bring-up stage.

See the [documentation index](docs/README.md) and [bring-up roadmap](docs/roadmap.md)
for the current plan and evidence requirements.

Initial work assumes a functioning ROCKNIX-ABL installation and writes only
removable media. Installing ABL and backing up or restoring Android are outside
Archneo's scope. See the [boot contract](docs/architecture/boot-contract.md)
before producing test media.

## Build entry points

```sh
make verify
make prepare-kernel
make kernel
sudo make image
```

See [building Archneo](docs/building.md) for host dependencies, outputs, and
the current reproducibility boundary.

## Upstream projects

Archneo is an independent project and is not affiliated with Arch Linux ARM or
ROCKNIX. It intends to build on their work while preserving attribution and
complying with the licences of each imported component.

- [Arch Linux ARM](https://archlinuxarm.org/)
- [ROCKNIX](https://github.com/ROCKNIX/distribution)
- [ROCKNIX-ABL](https://github.com/ROCKNIX/abl)
