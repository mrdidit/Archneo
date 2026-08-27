#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources
archneo_load_platform

[[ "$(id -u)" == "0" ]] || archneo_die "disk-image construction must run as root"

for command in blkid e2fsck fsck.vfat gzip losetup mkfs.ext4 mkfs.vfat \
  mount mountpoint rsync sgdisk sfdisk sha256sum sync truncate udevadm umount; do
  archneo_need_command "$command"
done

device="${ARCHNEO_DEVICE:-ayaneo-pocket-s-2k}"
rootfs="${ARCHNEO_BUILD_DIR}/rootfs/${device}"
device_out="${ARCHNEO_OUT_DIR}/${device}"
image_work_dir="${ARCHNEO_BUILD_DIR}/images/${device}"
mount_root="${ARCHNEO_BUILD_DIR}/mounts/${device}/root"
mount_home="${ARCHNEO_BUILD_DIR}/mounts/${device}/home"
mount_boot="${ARCHNEO_BUILD_DIR}/mounts/${device}/boot"
raw_image="${image_work_dir}/Archneo-${device}.img"
compressed_image="${device_out}/Archneo-${device}.img.gz"
compressed_partial="${compressed_image}.part"

"${SCRIPT_DIR}/prepare-rootfs.sh"
[[ -s "${device_out}/KERNEL" ]] || archneo_die "bootable KERNEL payload is missing"
[[ -s "${rootfs}/boot/initramfs-linux-archneo.img" ]] || \
  archneo_die "Archneo initramfs is missing"

mkdir -p -- "$image_work_dir" "$device_out" "$mount_root" "$mount_home" "$mount_boot"
for mount_dir in "$mount_boot" "$mount_home" "$mount_root"; do
  mountpoint -q "$mount_dir" && archneo_die "stale image mount found: ${mount_dir}"
done

cat > "${rootfs}/etc/fstab" <<EOF
# Archneo uses filesystem UUIDs so removable-media device numbering is irrelevant.
UUID=${ARCHNEO_ROOT_FS_UUID}  /      ext4  defaults,noatime  0 1
UUID=${ARCHNEO_BOOT_FS_UUID}  /boot  vfat  defaults,noatime,fmask=0022,dmask=0022  0 2
UUID=${ARCHNEO_HOME_FS_UUID}  /home  ext4  defaults,noatime  0 2
EOF

# 16 MiB pre-partition gap + 2 GiB boot + 30 GiB root + 1 GiB home seed
# + 2 MiB for alignment and the backup GPT.
image_size_mib=$((
  ABL_SYSTEM_PART_START_SECTORS / 2048 +
  ABL_SYSTEM_PART_SIZE_MIB +
  ARCHNEO_ROOT_SIZE_MIB +
  ARCHNEO_HOME_SEED_SIZE_MIB +
  2
))

archneo_log "creating persistent sparse image: ${raw_image}"
truncate -s "${image_size_mib}M" "$raw_image"
sgdisk --clear \
  --set-alignment=2048 \
  --disk-guid="$ARCHNEO_DISK_GUID" \
  --new="1:${ABL_SYSTEM_PART_START_SECTORS}:+${ABL_SYSTEM_PART_SIZE_MIB}M" \
  --typecode=1:0700 \
  --change-name=1:"$ROCKNIX_ABL_BOOT_LABEL" \
  --partition-guid=1:"$ARCHNEO_BOOT_PART_GUID" \
  --attributes=1:set:2 \
  --new="2:0:+${ARCHNEO_ROOT_SIZE_MIB}M" \
  --typecode=2:8300 \
  --change-name=2:"$ARCHNEO_ROOT_LABEL" \
  --partition-guid=2:"$ARCHNEO_ROOT_PART_GUID" \
  --new="3:0:+${ARCHNEO_HOME_SEED_SIZE_MIB}M" \
  --typecode=3:8300 \
  --change-name=3:"$ARCHNEO_HOME_LABEL" \
  --partition-guid=3:"$ARCHNEO_HOME_PART_GUID" \
  "$raw_image"

loop_device=""
mounted_root=0
mounted_home=0
mounted_boot=0
cleanup_image() {
  if (( mounted_boot )); then umount "$mount_boot" || true; fi
  if (( mounted_home )); then umount "$mount_home" || true; fi
  if (( mounted_root )); then umount "$mount_root" || true; fi
  if [[ -n "$loop_device" ]]; then losetup --detach "$loop_device" || true; fi
}
trap cleanup_image EXIT

loop_device="$(losetup --find --show --partscan "$raw_image")"
udevadm settle
boot_partition="${loop_device}p1"
root_partition="${loop_device}p2"
home_partition="${loop_device}p3"
for partition in "$boot_partition" "$root_partition" "$home_partition"; do
  [[ -b "$partition" ]] || archneo_die "loop partition did not appear: ${partition}"
done

mkfs.vfat -F 32 -n "$ROCKNIX_ABL_BOOT_LABEL" \
  -i "${ARCHNEO_BOOT_FS_UUID//-/}" "$boot_partition"
mkfs.ext4 -F -m 0 -L "$ARCHNEO_ROOT_LABEL" \
  -U "$ARCHNEO_ROOT_FS_UUID" "$root_partition"
mkfs.ext4 -F -m 0 -L "$ARCHNEO_HOME_LABEL" \
  -U "$ARCHNEO_HOME_FS_UUID" "$home_partition"

[[ "$(blkid -s UUID -o value "$boot_partition")" == "$ARCHNEO_BOOT_FS_UUID" ]] || \
  archneo_die "boot filesystem UUID mismatch"
[[ "$(blkid -s UUID -o value "$root_partition")" == "$ARCHNEO_ROOT_FS_UUID" ]] || \
  archneo_die "root filesystem UUID mismatch"
[[ "$(blkid -s UUID -o value "$home_partition")" == "$ARCHNEO_HOME_FS_UUID" ]] || \
  archneo_die "home filesystem UUID mismatch"

mount "$root_partition" "$mount_root"
mounted_root=1
mount "$home_partition" "$mount_home"
mounted_home=1
mount "$boot_partition" "$mount_boot"
mounted_boot=1

archneo_log "populating root, home, and ABL-facing filesystems"
rsync -aHAX --numeric-ids \
  --exclude='/boot/***' \
  --exclude='/home/***' \
  --exclude='/.archneo-complete' \
  "${rootfs}/." "$mount_root/"
install -d -m 0755 "${mount_root}/boot" "${mount_root}/home"
rsync -aHAX --numeric-ids "${rootfs}/home/." "$mount_home/"

install -m 0644 "${device_out}/KERNEL" "$mount_boot/KERNEL"
install -m 0644 "${device_out}/KERNEL.sha256" "$mount_boot/KERNEL.sha256"
install -m 0644 "${device_out}/build-manifest.txt" "$mount_boot/build-manifest.txt"
install -m 0644 "${rootfs}/boot/initramfs-linux-archneo.img" \
  "$mount_boot/initramfs-linux-archneo.img"
sync

umount "$mount_boot"
mounted_boot=0
umount "$mount_home"
mounted_home=0
umount "$mount_root"
mounted_root=0

set +e
e2fsck -pf "$root_partition"
root_fsck_status=$?
e2fsck -pf "$home_partition"
home_fsck_status=$?
set -e
(( root_fsck_status <= 1 && home_fsck_status <= 1 )) || \
  archneo_die "ext4 verification failed"
fsck.vfat -n "$boot_partition"

sfdisk --json "$loop_device" > "${device_out}/partition-table.json"
losetup --detach "$loop_device"
loop_device=""
trap - EXIT

{
  printf 'device=%s\n' "$device"
  printf 'image_size_mib=%s\n' "$image_size_mib"
  printf 'boot_size_mib=%s\n' "$ABL_SYSTEM_PART_SIZE_MIB"
  printf 'boot_label=%s\n' "$ROCKNIX_ABL_BOOT_LABEL"
  printf 'boot_uuid=%s\n' "$ARCHNEO_BOOT_FS_UUID"
  printf 'root_size_mib=%s\n' "$ARCHNEO_ROOT_SIZE_MIB"
  printf 'root_uuid=%s\n' "$ARCHNEO_ROOT_FS_UUID"
  printf 'home_seed_size_mib=%s\n' "$ARCHNEO_HOME_SEED_SIZE_MIB"
  printf 'home_uuid=%s\n' "$ARCHNEO_HOME_FS_UUID"
  printf 'rootfs_sha256=%s\n' "$(sha256sum -- "${ARCHNEO_CACHE_DIR}/downloads/ArchLinuxARM-aarch64-latest.tar.gz" | awk '{print $1}')"
  printf 'kernel_sha256=%s\n' "$(sha256sum -- "${device_out}/KERNEL" | awk '{print $1}')"
} > "${device_out}/image-manifest.txt"

archneo_log "compressing the image (the sparse raw image remains in the persistent build directory)"
gzip -1 -n -c -- "$raw_image" > "$compressed_partial"
mv -- "$compressed_partial" "$compressed_image"
(
  cd "$device_out"
  sha256sum "$(basename -- "$compressed_image")" > "$(basename -- "$compressed_image").sha256"
)

archneo_log "removable-media image ready: ${compressed_image}"
