#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources
archneo_load_platform

[[ "$(id -u)" == "0" ]] || archneo_die "rootfs preparation must run as root"

for command in bsdtar chroot find mount mountpoint qemu-aarch64-static rsync sha256sum tar umount; do
  archneo_need_command "$command"
done

device="${ARCHNEO_DEVICE:-ayaneo-pocket-s-2k}"
device_out="${ARCHNEO_BUILD_DIR}/artifacts/${device}"
modules_root="${device_out}/rootfs-overlay/lib/modules"
rootfs="${ARCHNEO_BUILD_DIR}/rootfs/${device}"
rootfs_archive="${ARCHNEO_CACHE_DIR}/downloads/ArchLinuxARM-aarch64-latest.tar.gz"
extra_firmware_archive="${ARCHNEO_CACHE_DIR}/downloads/rocknix-extra-firmware-${ROCKNIX_EXTRA_FIRMWARE_COMMIT}.tar.gz"
extra_firmware_stage="${ARCHNEO_BUILD_DIR}/firmware/rocknix-extra-${ROCKNIX_EXTRA_FIRMWARE_COMMIT}"

[[ -d "$modules_root" ]] || archneo_die "kernel modules are missing; run make kernel first"
mapfile -t kernel_releases < <(find "$modules_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
[[ "${#kernel_releases[@]}" == "1" ]] || \
  archneo_die "expected exactly one kernel module release"
kernel_release="${kernel_releases[0]}"

"${SCRIPT_DIR}/fetch-rootfs.sh"
"${SCRIPT_DIR}/fetch-firmware.sh"

mkdir -p -- "$rootfs" "$extra_firmware_stage"
if [[ -e "${rootfs}/.archneo-complete" ]]; then
  existing_schema="$(< "${rootfs}/.archneo-complete")"
else
  existing_schema=""
fi

if [[ "$existing_schema" == "$ARCHNEO_ROOTFS_SCHEMA:$kernel_release" ]]; then
  archneo_log "using prepared persistent rootfs: ${rootfs}"
  ARCHNEO_DEVICE="$device" \
  ARCHNEO_PACKAGE_KIND="bootable-image" \
  ARCHNEO_RAMDISK="${rootfs}/boot/initramfs-linux-archneo.img" \
    "${SCRIPT_DIR}/package-kernel.sh"
  exit 0
fi

if mountpoint -q "$rootfs"; then
  archneo_die "refusing to replace a mounted rootfs staging directory: ${rootfs}"
fi
find "$rootfs" -mindepth 1 -delete

archneo_log "extracting the verified Arch Linux ARM rootfs"
bsdtar -xpf "$rootfs_archive" -C "$rootfs"

if [[ ! -e "${extra_firmware_stage}/.archneo-complete" ]]; then
  find "$extra_firmware_stage" -mindepth 1 -delete
  tar -xzf "$extra_firmware_archive" --strip-components=1 -C "$extra_firmware_stage"
  touch "${extra_firmware_stage}/.archneo-complete"
fi

archneo_log "installing custom modules and pinned SM8550 firmware"
rsync -aHAX --numeric-ids "${device_out}/rootfs-overlay/." "$rootfs/"
rsync -aHAX --numeric-ids "${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/." "$rootfs/"

[[ "$(. "${rootfs}/etc/archneo.conf"; printf '%s' "$ARCHNEO_HOME_FS_UUID")" == \
  "$ARCHNEO_HOME_FS_UUID" ]] || archneo_die "runtime home UUID disagrees with platform.env"

install -m 0755 "${SCRIPT_DIR}/configure-rootfs.sh" \
  "${rootfs}/root/archneo-configure-rootfs.sh"
install -m 0755 "$(command -v qemu-aarch64-static)" \
  "${rootfs}/usr/bin/qemu-aarch64-static"
if [[ -L "${rootfs}/etc/resolv.conf" ]]; then
  unlink "${rootfs}/etc/resolv.conf"
fi
install -m 0644 /etc/resolv.conf "${rootfs}/etc/resolv.conf"

mounted_dev=0
mounted_proc=0
mounted_sys=0
cleanup_mounts() {
  if (( mounted_sys )); then umount -R "${rootfs}/sys" || true; fi
  if (( mounted_proc )); then umount "${rootfs}/proc" || true; fi
  if (( mounted_dev )); then umount -R "${rootfs}/dev" || true; fi
}
trap cleanup_mounts EXIT

mount --rbind /dev "${rootfs}/dev"
mount --make-rslave "${rootfs}/dev"
mounted_dev=1
mount -t proc proc "${rootfs}/proc"
mounted_proc=1
mount --rbind /sys "${rootfs}/sys"
mount --make-rslave "${rootfs}/sys"
mounted_sys=1

archneo_chroot() {
  # Ubuntu's qemu-user-static build has a host-oriented default interpreter
  # prefix. Inside this chroot, -L / makes guest ELF interpreters resolve from
  # the verified Arch Linux ARM root rather than QEMU's host prefix.
  chroot "$rootfs" /usr/bin/qemu-aarch64-static -L / "$@"
}

archneo_log "updating and configuring the aarch64 rootfs under qemu"
archneo_chroot /bin/true || \
  archneo_die "qemu could not execute aarch64 programs in the prepared rootfs"
archneo_chroot /bin/bash /root/archneo-configure-rootfs.sh "$kernel_release"

# Apply the pinned ROCKNIX firmware after the rolling system update so pacman
# cannot replace it, then generate the initramfs from the final tree. Upstream
# firmware comes from Arch's linux-firmware package and is version-recorded by
# the package manifest.
archneo_log "installing pinned firmware and generating the Archneo initramfs"
install -d -m 0755 "${rootfs}/usr/lib/firmware"
rsync -aHAX --numeric-ids --exclude='/.archneo-complete' \
  "${extra_firmware_stage}/SM8550/." "${rootfs}/usr/lib/firmware/"
archneo_chroot /usr/bin/mkinitcpio \
  -k "$kernel_release" \
  -c /etc/mkinitcpio.conf.d/archneo.conf \
  -g /boot/initramfs-linux-archneo.img

cleanup_mounts
mounted_dev=0
mounted_proc=0
mounted_sys=0
trap - EXIT

find "${rootfs}/root/archneo-configure-rootfs.sh" -maxdepth 0 -type f -delete
find "${rootfs}/usr/bin/qemu-aarch64-static" -maxdepth 0 -type f -delete

rootfs_sha="$(sha256sum -- "$rootfs_archive" | awk '{print $1}')"
{
  printf 'rootfs_sha256=%s\n' "$rootfs_sha"
  printf 'rootfs_signature_fingerprint=%s\n' "$ARCHLINUXARM_SIGNING_FINGERPRINT"
  printf 'kernel_release=%s\n' "$kernel_release"
  printf 'upstream_firmware_source=archlinuxarm-linux-firmware-package\n'
  printf 'rocknix_extra_firmware_commit=%s\n' "$ROCKNIX_EXTRA_FIRMWARE_COMMIT"
} > "${rootfs}/usr/share/archneo/rootfs-build.txt"
printf '%s:%s\n' "$ARCHNEO_ROOTFS_SCHEMA" "$kernel_release" > "${rootfs}/.archneo-complete"

ARCHNEO_DEVICE="$device" \
ARCHNEO_PACKAGE_KIND="bootable-image" \
ARCHNEO_RAMDISK="${rootfs}/boot/initramfs-linux-archneo.img" \
  "${SCRIPT_DIR}/package-kernel.sh"

archneo_log "prepared rootfs and real initramfs: ${rootfs}"
