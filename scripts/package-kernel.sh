#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources
archneo_load_platform

device="${ARCHNEO_DEVICE:-ayaneo-pocket-s-2k}"
package_kind="${ARCHNEO_PACKAGE_KIND:-compile-smoke}"

case "$device" in
  ayaneo-pocket-s-2k)
    dtb_name="qcs8550-ayaneo-pockets2k.dtb"
    ;;
  ayaneo-pocket-evo)
    dtb_name="qcs8550-ayaneo-pocketevo.dtb"
    ;;
  *)
    archneo_die "unsupported ARCHNEO_DEVICE: ${device}"
    ;;
esac

for command in gzip python3 sha256sum tar; do
  archneo_need_command "$command"
done

kernel_build_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-build"
mkbootimg_archive="${ARCHNEO_CACHE_DIR}/downloads/mkbootimg-${MKBOOTIMG_VERSION}.tar.gz"
mkbootimg_dir="${ARCHNEO_BUILD_DIR}/mkbootimg-${MKBOOTIMG_VERSION}"
device_out="${ARCHNEO_BUILD_DIR}/artifacts/${device}"
published_out="${ARCHNEO_OUT_DIR}/${device}"
image="${kernel_build_dir}/arch/arm64/boot/Image"
dtb="${kernel_build_dir}/arch/arm64/boot/dts/qcom/${dtb_name}"
kernel_gz="${device_out}/kernel.gz"
ramdisk="${device_out}/ramdisk"
kernel_payload="${device_out}/KERNEL"

[[ -f "$image" ]] || archneo_die "kernel Image was not built"
[[ -f "$dtb" ]] || archneo_die "device tree was not built: ${dtb}"
mkdir -p -- "$device_out" "$published_out"

archneo_fetch_https "$MKBOOTIMG_URL" "$MKBOOTIMG_SHA256" "$mkbootimg_archive"
if [[ ! -d "$mkbootimg_dir" ]]; then
  mkdir -p -- "$mkbootimg_dir"
  tar -xzf "$mkbootimg_archive" --strip-components=1 -C "$mkbootimg_dir"
fi
[[ -f "${mkbootimg_dir}/mkbootimg.py" ]] || archneo_die "mkbootimg.py is missing"

# ROCKNIX-ABL consumes an Android boot-image-v0 payload containing a gzip
# kernel followed by the selected device tree.
gzip -9 -n -c -- "$image" > "$kernel_gz"
cat -- "$dtb" >> "$kernel_gz"

if [[ -n "${ARCHNEO_RAMDISK:-}" ]]; then
  [[ -s "$ARCHNEO_RAMDISK" ]] || archneo_die "initramfs is missing or empty: ${ARCHNEO_RAMDISK}"
  cp -- "$ARCHNEO_RAMDISK" "$ramdisk"
  ramdisk_kind="archneo-initramfs"
else
  # This matches public ROCKNIX packaging and is useful only as a compile and
  # ABL-container smoke artifact. It cannot discover Archneo's UUID root.
  printf 'dummy' > "$ramdisk"
  ramdisk_kind="rocknix-dummy"
fi

cmdline="boot=LABEL=${ROCKNIX_ABL_BOOT_LABEL} disk=UUID=${ARCHNEO_ROOT_FS_UUID} root=UUID=${ARCHNEO_ROOT_FS_UUID} rootfstype=ext4 rw rootwait console=ttyMSM0,115200n8 console=tty0 loglevel=7 ignore_loglevel allow_mismatched_32bit_el0 fw_devlink.strict=1 pcie_ports=compat irqaffinity=0-2 cgroup.memory=nokmem,nosocket nosoftlockup usbcore.interrupt_interval_override=045e:028e:2"
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

(
  cd "$device_out"
  sha256sum KERNEL > KERNEL.sha256
)

{
  printf 'device=%s\n' "$device"
  printf 'package_kind=%s\n' "$package_kind"
  printf 'ramdisk_kind=%s\n' "$ramdisk_kind"
  printf 'ramdisk_sha256=%s\n' "$(sha256sum -- "$ramdisk" | awk '{print $1}')"
  printf 'dtb=%s\n' "$dtb_name"
  printf 'linux_version=%s\n' "$LINUX_VERSION"
  printf 'linux_sha256=%s\n' "$LINUX_SHA256"
  printf 'rocknix_distribution_commit=%s\n' "$ROCKNIX_DISTRIBUTION_COMMIT"
  printf 'mkbootimg_commit=%s\n' "$MKBOOTIMG_VERSION"
  printf 'cmdline=%s\n' "$cmdline"
} > "${device_out}/build-manifest.txt"

cp -a "${device_out}/KERNEL" \
  "${device_out}/KERNEL.sha256" \
  "${device_out}/build-manifest.txt" \
  "${device_out}/kernel.gz" \
  "${device_out}/ramdisk" \
  "$published_out/"

archneo_log "ABL payload ready: ${published_out}/KERNEL (${ramdisk_kind})"
