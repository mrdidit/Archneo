#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources
archneo_load_platform
archneo_load_device

device="$ARCHNEO_DEVICE"
package_kind="${ARCHNEO_PACKAGE_KIND:-direct-root}"
selected_dtb_name="$ARCHNEO_SELECTED_DTB"

for command in cpio find gzip md5sum python3 sed sha256sum sort tar; do
  archneo_need_command "$command"
done

kernel_build_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-build"
mkbootimg_archive="${ARCHNEO_CACHE_DIR}/downloads/mkbootimg-${MKBOOTIMG_VERSION}.tar.gz"
mkbootimg_dir="${ARCHNEO_BUILD_DIR}/mkbootimg-${MKBOOTIMG_VERSION}"
device_out="${ARCHNEO_BUILD_DIR}/artifacts/${device}"
published_out="${ARCHNEO_OUT_DIR}/${device}"
image="${kernel_build_dir}/arch/arm64/boot/Image"
dt_source_dir="${ARCHNEO_CACHE_DIR}/rocknix-distribution/projects/ROCKNIX/devices/SM8550/linux/dts/qcom"
dt_build_dir="${kernel_build_dir}/arch/arm64/boot/dts/qcom"
kernel_gz="${device_out}/kernel.gz"
ramdisk="${device_out}/ramdisk"
kernel_payload="${device_out}/KERNEL"
external_initramfs="${ARCHNEO_EXTERNAL_INITRAMFS:-}"

[[ -f "$image" ]] || archneo_die "kernel Image was not built"
mapfile -t dtb_names < <(
  find "$dt_source_dir" -maxdepth 1 -type f -name 'qcs8550-*.dts' \
    -printf '%f\n' | sed 's/\.dts$/.dtb/' | LC_ALL=C sort
)
[[ "${#dtb_names[@]}" -gt 0 ]] || archneo_die "no ROCKNIX SM8550 device trees found"
printf '%s\n' "${dtb_names[@]}" | grep -Fxq "$selected_dtb_name" || \
  archneo_die "selected device tree is absent from the SM8550 set: ${selected_dtb_name}"
for dtb_name in "${dtb_names[@]}"; do
  [[ -f "${dt_build_dir}/${dtb_name}" ]] || \
    archneo_die "device tree was not built: ${dt_build_dir}/${dtb_name}"
  grep -aFq '__symbols__' "${dt_build_dir}/${dtb_name}" || \
    archneo_die "device tree lacks ROCKNIX overlay symbols: ${dtb_name}"
done
mkdir -p -- "$device_out" "$published_out"

archneo_fetch_https "$MKBOOTIMG_URL" "$MKBOOTIMG_SHA256" "$mkbootimg_archive"
if [[ ! -d "$mkbootimg_dir" ]]; then
  mkdir -p -- "$mkbootimg_dir"
  tar -xzf "$mkbootimg_archive" --strip-components=1 -C "$mkbootimg_dir"
fi
[[ -f "${mkbootimg_dir}/mkbootimg.py" ]] || archneo_die "mkbootimg.py is missing"

# ROCKNIX-ABL consumes an Android boot-image-v0 payload containing a gzip
# kernel followed by the complete, deterministically ordered SM8550 DTB set.
# A Pocket S 2K hardware report confirms that ABL exposes a selected SM8550
# model when it is present in the appended set. Retain that envelope for EVO.
gzip -9 -n -c -- "$image" > "$kernel_gz"
for dtb_name in "${dtb_names[@]}"; do
  cat -- "${dt_build_dir}/${dtb_name}" >> "$kernel_gz"
done

if [[ -n "$external_initramfs" ]]; then
  [[ -s "$external_initramfs" ]] || \
    archneo_die "external initramfs is missing or empty: ${external_initramfs}"
  [[ "$external_initramfs" == *.cpio.gz ]] || \
    archneo_die "external initramfs must use the .cpio.gz suffix"
  # This is a file inside the removable SD image, not an Android partition.
  # ABL consumes the Android boot-image-v0 container at /KERNEL and forwards
  # this functional ramdisk to Linux as its early userspace.
  cp -- "$external_initramfs" "$ramdisk"
  ramdisk_kind="archneo-initramfs"
  initramfs_delivery="android-boot-ramdisk"
  initramfs_sha256="$(sha256sum -- "$external_initramfs" | awk '{print $1}')"
  root_argument="root=PARTUUID=${ARCHNEO_ROOT_PART_GUID}"
  diagnostic_arguments="boot=LABEL=${ROCKNIX_ABL_BOOT_LABEL} rd.debug rd.log=all"
  usb_diagnostic="cdc-acm:ttyGS0"
  usb_console_argument="console=ttyGS0,115200n8"
else
  # The bring-up image follows the hardware-proven initramfs-free SM8550 path.
  # Linux can resolve a GPT PARTUUID directly; filesystem UUID resolution would
  # require early userspace. A valid empty newc archive avoids a harmless
  # initramfs-unpacking warning without adding a second boot environment.
  printf '' | cpio --quiet -o -H newc > "$ramdisk"
  ramdisk_kind="empty-newc"
  initramfs_delivery="none-direct-root"
  initramfs_sha256="none"
  root_argument="root=PARTUUID=${ARCHNEO_ROOT_PART_GUID}"
  diagnostic_arguments=""
  usb_diagnostic="none"
  usb_console_argument=""
fi

cmdline="${root_argument} rootfstype=ext4 rw rootwait ${diagnostic_arguments} console=ttyMSM0,115200n8 console=tty0 ${usb_console_argument} systemd.unit=multi-user.target systemd.show_status=1 loglevel=7 ignore_loglevel drm.debug=0x1ff log_buf_len=4M allow_mismatched_32bit_el0 fw_devlink.strict=1 pcie_ports=compat irqaffinity=0-2 cgroup.memory=nokmem,nosocket nosoftlockup usbcore.interrupt_interval_override=045e:028e:2"
(( ${#cmdline} <= 511 )) || archneo_die "Android boot-image v0 command line exceeds 511 bytes"

python3 "${mkbootimg_dir}/mkbootimg.py" \
  --kernel "$kernel_gz" \
  --ramdisk "$ramdisk" \
  --kernel_offset 0x00000000 \
  --ramdisk_offset 0x00000000 \
  --tags_offset 0x00000000 \
  --os_version "$ABL_OS_VERSION" \
  --os_patch_level "$ABL_OS_PATCH_LEVEL" \
  --header_version 0 \
  --cmdline "$cmdline" \
  -o "$kernel_payload"

validator_args=(
  "$kernel_payload"
  --expected-kernel "$kernel_gz"
  --expected-ramdisk "$ramdisk"
  --expected-cmdline "$cmdline"
  --expected-dtb-count "${#dtb_names[@]}"
  --require-dtb-symbols
)
python3 "${SCRIPT_DIR}/verify-boot-image.py" "${validator_args[@]}"

(
  cd "$device_out"
  md5sum KERNEL > KERNEL.md5
  sha256sum KERNEL > KERNEL.sha256
)

dtb_list="$(IFS=,; printf '%s' "${dtb_names[*]}")"

{
  printf 'device=%s\n' "$device"
  printf 'package_kind=%s\n' "$package_kind"
  printf 'ramdisk_kind=%s\n' "$ramdisk_kind"
  printf 'ramdisk_sha256=%s\n' "$(sha256sum -- "$ramdisk" | awk '{print $1}')"
  printf 'initramfs_delivery=%s\n' "$initramfs_delivery"
  printf 'initramfs_sha256=%s\n' "$initramfs_sha256"
  printf 'usb_diagnostic=%s\n' "$usb_diagnostic"
  printf 'selected_dtb=%s\n' "$selected_dtb_name"
  printf 'dtb_selection=abl-appended-set\n'
  printf 'dtb_symbols=required-present\n'
  printf 'dtb_count=%s\n' "${#dtb_names[@]}"
  printf 'dtbs=%s\n' "$dtb_list"
  printf 'linux_version=%s\n' "$LINUX_VERSION"
  printf 'linux_sha256=%s\n' "$LINUX_SHA256"
  printf 'rocknix_distribution_commit=%s\n' "$ROCKNIX_DISTRIBUTION_COMMIT"
  printf 'mkbootimg_commit=%s\n' "$MKBOOTIMG_VERSION"
  printf 'cmdline=%s\n' "$cmdline"
} > "${device_out}/build-manifest.txt"

cp -a "${device_out}/KERNEL" \
  "${device_out}/KERNEL.md5" \
  "${device_out}/KERNEL.sha256" \
  "${device_out}/build-manifest.txt" \
  "${device_out}/kernel.gz" \
  "${device_out}/ramdisk" \
  "$published_out/"

archneo_log "ABL payload ready: ${published_out}/KERNEL (${ramdisk_kind})"
