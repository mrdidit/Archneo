#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources
archneo_load_platform

CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
JOBS="${JOBS:-$(nproc)}"
device="${ARCHNEO_DEVICE:-ayaneo-pocket-s-2k}"

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

for command in "${CROSS_COMPILE}gcc" gzip make nproc python3 sha256sum tar; do
  archneo_need_command "$command"
done

"${SCRIPT_DIR}/prepare-kernel.sh"

source_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-source"
kernel_build_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-build"
mkbootimg_archive="${ARCHNEO_CACHE_DIR}/downloads/mkbootimg-${MKBOOTIMG_VERSION}.tar.gz"
mkbootimg_dir="${ARCHNEO_BUILD_DIR}/mkbootimg-${MKBOOTIMG_VERSION}"
device_out="${ARCHNEO_BUILD_DIR}/artifacts/${device}"
published_out="${ARCHNEO_OUT_DIR}/${device}"

mkdir -p -- "$kernel_build_dir" "$device_out"

if [[ ! -f "${kernel_build_dir}/.config" ]]; then
  cp -- "${source_dir}/.archneo.config" "${kernel_build_dir}/.config"
fi

make_args=(
  -C "$source_dir"
  "O=${kernel_build_dir}"
  ARCH=arm64
  "CROSS_COMPILE=${CROSS_COMPILE}"
)

archneo_log "resolving the pinned kernel configuration"
make "${make_args[@]}" olddefconfig

archneo_log "building Linux, modules, and ${dtb_name}"
make -j"$JOBS" "${make_args[@]}" \
  Image modules "qcom/${dtb_name}"

modules_dir="${device_out}/rootfs-overlay"
make "${make_args[@]}" "INSTALL_MOD_PATH=${modules_dir}" modules_install
find "${modules_dir}/lib/modules" -type l \( -name build -o -name source \) -delete

archneo_fetch_https "$MKBOOTIMG_URL" "$MKBOOTIMG_SHA256" "$mkbootimg_archive"
if [[ ! -d "$mkbootimg_dir" ]]; then
  mkdir -p -- "$mkbootimg_dir"
  tar -xzf "$mkbootimg_archive" --strip-components=1 -C "$mkbootimg_dir"
fi
[[ -f "${mkbootimg_dir}/mkbootimg.py" ]] || archneo_die "mkbootimg.py is missing"

image="${kernel_build_dir}/arch/arm64/boot/Image"
dtb="${kernel_build_dir}/arch/arm64/boot/dts/qcom/${dtb_name}"
kernel_gz="${device_out}/kernel.gz"
ramdisk="${device_out}/ramdisk"
kernel_payload="${device_out}/KERNEL"

[[ -f "$image" ]] || archneo_die "kernel Image was not built"
[[ -f "$dtb" ]] || archneo_die "device tree was not built: ${dtb}"

# ROCKNIX-ABL consumes an Android boot-image-v0 payload containing a gzip
# kernel followed by one or more DTBs. The first bring-up emits only the
# selected device's DTB, preventing accidental cross-device images.
gzip -9 -n -c -- "$image" > "$kernel_gz"
cat -- "$dtb" >> "$kernel_gz"
printf 'dummy' > "$ramdisk"

cmdline="boot=LABEL=${ROCKNIX_ABL_BOOT_LABEL} disk=LABEL=${ARCHNEO_ROOT_LABEL} root=LABEL=${ARCHNEO_ROOT_LABEL} rootfstype=ext4 rw rootwait console=ttyMSM0,115200n8 console=tty0 loglevel=7 ignore_loglevel allow_mismatched_32bit_el0 fw_devlink.strict=1 pcie_ports=compat irqaffinity=0-2 cgroup.memory=nokmem,nosocket nosoftlockup usbcore.interrupt_interval_override=045e:028e:2"

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
  printf 'dtb=%s\n' "$dtb_name"
  printf 'linux_version=%s\n' "$LINUX_VERSION"
  printf 'linux_sha256=%s\n' "$LINUX_SHA256"
  printf 'rocknix_distribution_commit=%s\n' "$ROCKNIX_DISTRIBUTION_COMMIT"
  printf 'mkbootimg_commit=%s\n' "$MKBOOTIMG_VERSION"
  printf 'cmdline=%s\n' "$cmdline"
} > "${device_out}/build-manifest.txt"

mkdir -p -- "$published_out"
cp -a "${device_out}/." "$published_out/"

archneo_log "ABL payload ready: ${published_out}/KERNEL"
