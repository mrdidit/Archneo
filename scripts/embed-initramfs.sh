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

for command in "${CROSS_COMPILE}gcc" cmp grep make nproc sha256sum; do
  archneo_need_command "$command"
done

[[ -n "$initramfs" && -s "$initramfs" ]] || \
  archneo_die "ARCHNEO_INITRAMFS must name a non-empty initramfs"
[[ "$initramfs" == *.cpio.gz ]] || \
  archneo_die "the kernel-built-in initramfs must use the .cpio.gz suffix"

source_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-source"
kernel_build_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-build"
base_config="${source_dir}/.archneo.config"
kernel_config="${kernel_build_dir}/.config"

[[ -f "$base_config" ]] || archneo_die "prepared kernel configuration is missing"
[[ -d "$kernel_build_dir" ]] || archneo_die "kernel output is missing; run make kernel first"

# CONFIG_INITRAMFS_SOURCE accepts an existing compressed cpio archive. Start
# from the canonical config so repeated image/compile-smoke builds cannot leak
# an earlier rootfs path into a later payload.
cp -- "$base_config" "$kernel_config"
"${source_dir}/scripts/config" --file "$kernel_config" \
  --set-str CONFIG_INITRAMFS_SOURCE "$initramfs" \
  --enable USB_CONFIGFS_ACM \
  --enable U_SERIAL_CONSOLE

make_args=(
  -C "$source_dir"
  "O=${kernel_build_dir}"
  ARCH=arm64
  "CROSS_COMPILE=${CROSS_COMPILE}"
)

archneo_log "resolving the kernel-built-in Archneo initramfs configuration"
make "${make_args[@]}" olddefconfig
grep -Fxq "CONFIG_INITRAMFS_SOURCE=\"${initramfs}\"" "$kernel_config" || \
  archneo_die "kernel configuration did not retain the Archneo initramfs path"
for usb_console_setting in \
  CONFIG_USB_CONFIGFS=y \
  CONFIG_USB_CONFIGFS_ACM=y \
  CONFIG_USB_U_SERIAL=y \
  CONFIG_USB_F_ACM=y \
  CONFIG_U_SERIAL_CONSOLE=y; do
  grep -Fxq "$usb_console_setting" "$kernel_config" || \
    archneo_die "diagnostic kernel did not retain ${usb_console_setting}"
done

archneo_log "relinking Linux with the Archneo initramfs built in"
make -j"$JOBS" "${make_args[@]}" DTC_FLAGS=-@ Image "qcom/${dtb_name}"
embedded_initramfs="${kernel_build_dir}/usr/initramfs_inc_data"
[[ -s "$embedded_initramfs" ]] || \
  archneo_die "kernel build did not produce embedded initramfs data"
cmp -s -- "$initramfs" "$embedded_initramfs" || \
  archneo_die "kernel embedded-initramfs data differs from the Archneo archive"

ARCHNEO_DEVICE="$device" \
ARCHNEO_PACKAGE_KIND="early-boot-diagnostic" \
ARCHNEO_BUILTIN_INITRAMFS="$initramfs" \
  "${SCRIPT_DIR}/package-kernel.sh"
