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
    selected_dtb_name="qcs8550-ayaneo-pockets2k.dtb"
    ;;
  ayaneo-pocket-evo)
    selected_dtb_name="qcs8550-ayaneo-pocketevo.dtb"
    ;;
  *)
    archneo_die "unsupported ARCHNEO_DEVICE: ${device}"
    ;;
esac

for command in "${CROSS_COMPILE}gcc" find grep make nproc sed sort; do
  archneo_need_command "$command"
done

"${SCRIPT_DIR}/prepare-kernel.sh"

source_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-source"
kernel_build_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-build"
device_out="${ARCHNEO_BUILD_DIR}/artifacts/${device}"
dt_source_dir="${ARCHNEO_CACHE_DIR}/rocknix-distribution/projects/ROCKNIX/devices/SM8550/linux/dts/qcom"

mapfile -t dtb_names < <(
  find "$dt_source_dir" -maxdepth 1 -type f -name 'qcs8550-*.dts' \
    -printf '%f\n' | sed 's/\.dts$/.dtb/' | LC_ALL=C sort
)
[[ "${#dtb_names[@]}" -gt 0 ]] || archneo_die "no ROCKNIX SM8550 device trees found"
printf '%s\n' "${dtb_names[@]}" | grep -Fxq "$selected_dtb_name" || \
  archneo_die "selected device tree is absent from the SM8550 set: ${selected_dtb_name}"
dtb_targets=()
for dtb_name in "${dtb_names[@]}"; do
  dtb_targets+=("qcom/${dtb_name}")
done

mkdir -p -- "$kernel_build_dir" "$device_out"

# An older complete-image build may have linked an initramfs into this output
# tree. Always restore the canonical direct-root configuration before building.
cp -- "${source_dir}/.archneo.config" "${kernel_build_dir}/.config"

make_args=(
  -C "$source_dir"
  "O=${kernel_build_dir}"
  ARCH=arm64
  "CROSS_COMPILE=${CROSS_COMPILE}"
)

archneo_log "resolving the pinned kernel configuration"
make "${make_args[@]}" olddefconfig

archneo_log "building Linux, modules, and ${#dtb_names[@]} ROCKNIX SM8550 device trees"
make -j"$JOBS" "${make_args[@]}" \
  Image modules "${dtb_targets[@]}"

modules_dir="${device_out}/rootfs-overlay"
make "${make_args[@]}" "INSTALL_MOD_PATH=${modules_dir}" modules_install
find "${modules_dir}/lib/modules" -type l \( -name build -o -name source \) -delete

ARCHNEO_DEVICE="$device" \
ARCHNEO_PACKAGE_KIND="direct-root" \
  "${SCRIPT_DIR}/package-kernel.sh"
