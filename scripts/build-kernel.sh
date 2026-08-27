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

for command in "${CROSS_COMPILE}gcc" make nproc; do
  archneo_need_command "$command"
done

"${SCRIPT_DIR}/prepare-kernel.sh"

source_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-source"
kernel_build_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-build"
device_out="${ARCHNEO_BUILD_DIR}/artifacts/${device}"

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

ARCHNEO_DEVICE="$device" \
ARCHNEO_PACKAGE_KIND="compile-smoke" \
  "${SCRIPT_DIR}/package-kernel.sh"
