#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources
archneo_load_platform
archneo_load_device

[[ "$(id -u)" == "0" ]] || archneo_die "rootfs preparation must run as root"

for command in bsdtar chroot find mount mountpoint qemu-aarch64-static rsync sha256sum tar umount; do
  archneo_need_command "$command"
done

device="$ARCHNEO_DEVICE"
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

rootfs_identity="${ARCHNEO_ROOTFS_SCHEMA}:${kernel_release}:${ARCHNEO_HOME_FS_UUID}"
if [[ "$existing_schema" == "$rootfs_identity" ]]; then
  archneo_log "using prepared persistent rootfs: ${rootfs}"
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

archneo_log "installing custom modules and the Archneo rootfs policy overlay"
# modules_install emits lib/modules below INSTALL_MOD_PATH. Copy the contents
# into Arch's canonical usr-merged location; syncing the top-level lib directory
# would replace the rootfs's /lib -> usr/lib compatibility symlink.
install -d -m 0755 "${rootfs}/usr/lib/modules"
rsync -aHAX --chown=0:0 "${modules_root}/." "${rootfs}/usr/lib/modules/"
rsync -aHAX --chown=0:0 "${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/." "$rootfs/"
chown 0:0 "$rootfs"

{
  printf '# Generated from the selected Archneo device profile.\n'
  printf 'ARCHNEO_DEVICE=%q\n' "$ARCHNEO_DEVICE"
  printf 'ARCHNEO_HOME_FS_UUID=%q\n' "$ARCHNEO_HOME_FS_UUID"
} > "${rootfs}/etc/archneo.conf"
chown 0:0 "${rootfs}/etc/archneo.conf"
chmod 0644 "${rootfs}/etc/archneo.conf"

[[ -L "${rootfs}/lib" && "$(readlink "${rootfs}/lib")" == "usr/lib" ]] || \
  archneo_die "prepared rootfs lost its /lib -> usr/lib compatibility symlink"
[[ -x "${rootfs}/usr/lib/ld-linux-aarch64.so.1" ]] || \
  archneo_die "prepared rootfs is missing its aarch64 ELF interpreter"
[[ -L "${rootfs}/bin" && "$(readlink "${rootfs}/bin")" == "usr/bin" ]] || \
  archneo_die "prepared rootfs lost its /bin -> usr/bin compatibility symlink"
for root_owned_path in "$rootfs" "${rootfs}/etc" "${rootfs}/usr"; do
  [[ "$(stat -c '%u:%g' "$root_owned_path")" == "0:0" ]] || \
    archneo_die "system path is not root-owned: ${root_owned_path}"
done

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
mounted_rootfs=0
cleanup_mounts() {
  if (( mounted_sys )); then umount -R "${rootfs}/sys" || true; fi
  if (( mounted_proc )); then umount "${rootfs}/proc" || true; fi
  if (( mounted_dev )); then umount -R "${rootfs}/dev" || true; fi
  if (( mounted_rootfs )); then umount "$rootfs" || true; fi
}
trap cleanup_mounts EXIT

# Give the chroot a real mount boundary. Pacman's CheckSpace implementation
# resolves cache paths through /proc/self/mountinfo; a plain directory chroot
# has no chroot-visible mount point to associate with /var/cache/pacman/pkg.
mount --bind "$rootfs" "$rootfs"
mounted_rootfs=1
mount --make-private "$rootfs"
mount --rbind /dev "${rootfs}/dev"
mount --make-rslave "${rootfs}/dev"
mounted_dev=1
mount -t proc proc "${rootfs}/proc"
mounted_proc=1
mount --rbind /sys "${rootfs}/sys"
mount --make-rslave "${rootfs}/sys"
mounted_sys=1

archneo_chroot() {
  # Make the guest root explicit rather than inheriting a distribution-specific
  # QEMU interpreter prefix.
  chroot "$rootfs" /usr/bin/qemu-aarch64-static -L / "$@"
}

archneo_log "updating and configuring the aarch64 rootfs under qemu"
archneo_chroot /bin/true || \
  archneo_die "qemu could not execute aarch64 programs in the prepared rootfs"
archneo_chroot /bin/bash /root/archneo-configure-rootfs.sh "$kernel_release"

# Apply the pinned ROCKNIX firmware after the rolling system update so pacman
# cannot replace it. Upstream firmware comes from Arch's linux-firmware package
# and is version-recorded by the package manifest. The bring-up kernel mounts
# ext4 directly and intentionally has no functional initramfs.
archneo_log "installing pinned firmware for the direct-root Archneo image"
install -d -m 0755 "${rootfs}/usr/lib/firmware"
rsync -aHAX --chown=0:0 --exclude='/.archneo-complete' \
  "${extra_firmware_stage}/SM8550/." "${rootfs}/usr/lib/firmware/"

cleanup_mounts
mounted_dev=0
mounted_proc=0
mounted_sys=0
mounted_rootfs=0
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
printf '%s\n' "$rootfs_identity" > "${rootfs}/.archneo-complete"

archneo_log "prepared direct-root Archneo rootfs: ${rootfs}"
