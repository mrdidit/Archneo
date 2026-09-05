#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources
archneo_load_platform
archneo_load_device

CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
JOBS="${JOBS:-$(nproc)}"
device="$ARCHNEO_DEVICE"
initramfs="${ARCHNEO_INITRAMFS:-}"
dtb_name="$ARCHNEO_SELECTED_DTB"

for command in "${CROSS_COMPILE}gcc" grep make nproc; do
  archneo_need_command "$command"
done

[[ -n "$initramfs" && -s "$initramfs" ]] || \
  archneo_die "ARCHNEO_INITRAMFS must name a non-empty initramfs"
[[ "$initramfs" == *.cpio.gz ]] || \
  archneo_die "the diagnostic initramfs must use the .cpio.gz suffix"

source_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-source"
kernel_build_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-build"
base_config="${source_dir}/.archneo.config"
kernel_config="${kernel_build_dir}/.config"

[[ -f "$base_config" ]] || archneo_die "prepared kernel configuration is missing"
[[ -d "$kernel_build_dir" ]] || archneo_die "kernel output is missing; run make kernel first"

# Keep the functional initramfs outside Image so ROCKNIX-ABL receives it in
# the standard Android boot-image ramdisk field. Only the USB gadget path is
# added to the otherwise canonical Archneo kernel configuration.
cp -- "$base_config" "$kernel_config"
"${source_dir}/scripts/config" --file "$kernel_config" \
  --set-str INITRAMFS_SOURCE "" \
  --enable DEBUG_FS \
  --enable USB_CONFIGFS \
  --enable USB_CONFIGFS_ACM \
  --enable USB_U_SERIAL \
  --enable USB_F_ACM \
  --enable U_SERIAL_CONSOLE

make_args=(
  -C "$source_dir"
  "O=${kernel_build_dir}"
  ARCH=arm64
  "CROSS_COMPILE=${CROSS_COMPILE}"
)

archneo_log "resolving the external-initramfs diagnostic kernel configuration"
make "${make_args[@]}" olddefconfig
grep -Fxq 'CONFIG_INITRAMFS_SOURCE=""' "$kernel_config" || \
  archneo_die "diagnostic kernel unexpectedly embeds an initramfs"
for diagnostic_setting in \
  CONFIG_CONFIGFS_FS=y \
  CONFIG_DEBUG_FS=y \
  CONFIG_USB_GADGET=y \
  CONFIG_USB_DWC3=y \
  CONFIG_USB_DWC3_DUAL_ROLE=y \
  CONFIG_USB_DWC3_QCOM=y \
  CONFIG_USB_CONFIGFS=y \
  CONFIG_USB_CONFIGFS_ACM=y \
  CONFIG_USB_LIBCOMPOSITE=y \
  CONFIG_USB_U_SERIAL=y \
  CONFIG_USB_F_ACM=y \
  CONFIG_U_SERIAL_CONSOLE=y; do
  grep -Fxq "$diagnostic_setting" "$kernel_config" || \
    archneo_die "diagnostic kernel did not retain ${diagnostic_setting}"
done

archneo_log "relinking Linux with built-in SM8550 USB gadget support"
make -j"$JOBS" "${make_args[@]}" DTC_FLAGS=-@ Image "qcom/${dtb_name}"

ARCHNEO_DEVICE="$device" \
ARCHNEO_PACKAGE_KIND="early-boot-diagnostic" \
ARCHNEO_EXTERNAL_INITRAMFS="$initramfs" \
  "${SCRIPT_DIR}/package-kernel.sh"
