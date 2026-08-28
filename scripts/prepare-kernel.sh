#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources

for command in git patch sha256sum tar; do
  archneo_need_command "$command"
done

"${SCRIPT_DIR}/fetch-rocknix.sh"

rocknix_dir="${ARCHNEO_CACHE_DIR}/rocknix-distribution"
linux_archive="${ARCHNEO_CACHE_DIR}/downloads/linux-${LINUX_VERSION}.tar.xz"
source_dir="${ARCHNEO_BUILD_DIR}/linux-${LINUX_VERSION}-sm8550-source"
source_id="schema=3 linux=${LINUX_SHA256} rocknix=${ROCKNIX_DISTRIBUTION_COMMIT}"
marker="${source_dir}/.archneo-source-id"

archneo_fetch_https "$LINUX_URL" "$LINUX_SHA256" "$linux_archive"

prepared_config_is_valid() {
  local config="$1"
  grep -Fxq 'CONFIG_INITRAMFS_SOURCE=""' "$config" &&
    grep -Fxq 'CONFIG_DEFAULT_HOSTNAME="archneo"' "$config" &&
    grep -Fxq 'CONFIG_LOCALVERSION="-archneo"' "$config" &&
    grep -Fxq '# CONFIG_LOCALVERSION_AUTO is not set' "$config"
}

if [[ -d "$source_dir" ]]; then
  if [[ -f "$marker" ]] && [[ "$(<"$marker")" == "$source_id" ]] && \
    prepared_config_is_valid "${source_dir}/.archneo.config" && \
    [[ ! -e "${source_dir}/.config" ]]; then
    archneo_log "prepared kernel source already matches the lock"
    exit 0
  fi
  archneo_die "kernel source exists with a different or missing source marker: ${source_dir}"
fi

mkdir -p -- "$ARCHNEO_BUILD_DIR"
work_dir="$(mktemp -d "${ARCHNEO_BUILD_DIR}/.linux-source.XXXXXX")"
cleanup() {
  if [[ -n "${work_dir:-}" && -d "$work_dir" ]]; then
    rm -rf -- "$work_dir"
  fi
}
trap cleanup EXIT INT TERM

archneo_log "extracting Linux ${LINUX_VERSION}"
tar -xJf "$linux_archive" --strip-components=1 -C "$work_dir"

patch_count=0
apply_patch_directory() {
  local directory="$1"
  local patch_file

  [[ -d "$directory" ]] || archneo_die "missing ROCKNIX patch directory: ${directory}"
  while IFS= read -r -d '' patch_file; do
    archneo_log "applying ${patch_file#"${rocknix_dir}/"}"
    patch --batch --forward -d "$work_dir" -p1 < "$patch_file"
    patch_count=$((patch_count + 1))
  done < <(find "$directory" -maxdepth 1 -type f -name '*.patch' -print0 | LC_ALL=C sort -z)
}

# This reproduces ROCKNIX's selected order: project mainline patches, the
# matching kernel-version directory, then the direct SM8550 patch directory.
apply_patch_directory "${rocknix_dir}/projects/ROCKNIX/packages/linux/patches/mainline"
apply_patch_directory "${rocknix_dir}/projects/ROCKNIX/packages/linux/patches/${LINUX_VERSION}"
apply_patch_directory "${rocknix_dir}/projects/ROCKNIX/devices/SM8550/patches/linux"

local_patch_directory="${ARCHNEO_PROJECT_ROOT}/config/kernel/patches"
if [[ -d "$local_patch_directory" ]]; then
  while IFS= read -r -d '' patch_file; do
    archneo_log "applying local patch ${patch_file#"${ARCHNEO_PROJECT_ROOT}/"}"
    patch --batch --forward -d "$work_dir" -p1 < "$patch_file"
    patch_count=$((patch_count + 1))
  done < <(find "$local_patch_directory" -maxdepth 1 -type f -name '*.patch' -print0 | LC_ALL=C sort -z)
fi

[[ "$patch_count" -gt 0 ]] || archneo_die "no ROCKNIX patches were selected"

dts_source="${rocknix_dir}/projects/ROCKNIX/devices/SM8550/linux/dts"
kernel_config="${rocknix_dir}/projects/ROCKNIX/devices/SM8550/linux/linux.aarch64.conf"
[[ -f "${dts_source}/qcom/qcs8550-ayaneo-pockets2k.dts" ]] || \
  archneo_die "Pocket S 2K device tree is missing from the pinned ROCKNIX source"
[[ -f "${dts_source}/qcom/qcs8550-ayaneo-pocketevo.dts" ]] || \
  archneo_die "Pocket EVO device tree is missing from the pinned ROCKNIX source"
[[ -f "$kernel_config" ]] || archneo_die "pinned ROCKNIX kernel config is missing"

archneo_log "copying the ROCKNIX SM8550 device-tree sources"
cp -a "${dts_source}/." "${work_dir}/arch/arm64/boot/dts/"
cp -- "$kernel_config" "${work_dir}/.config"
cp -- "${ARCHNEO_PROJECT_ROOT}/config/kernel/archneo-sm8550.fragment" \
  "${work_dir}/.archneo.fragment"

# The ROCKNIX config embeds its appliance initramfs. Archneo instead mounts an
# ordinary ext4 root, so the embedded initramfs source must be empty.
(
  cd "$work_dir"
  ./scripts/kconfig/merge_config.sh -m .config .archneo.fragment
)
rm -- "${work_dir}/.archneo.fragment"
prepared_config_is_valid "${work_dir}/.config" || \
  archneo_die "failed to apply the Archneo kernel configuration delta"
mv -- "${work_dir}/.config" "${work_dir}/.archneo.config"

printf '%s\n' "$source_id" > "${work_dir}/.archneo-source-id"
{
  printf 'linux_version=%s\n' "$LINUX_VERSION"
  printf 'linux_sha256=%s\n' "$LINUX_SHA256"
  printf 'rocknix_distribution_commit=%s\n' "$ROCKNIX_DISTRIBUTION_COMMIT"
  printf 'rocknix_patch_count=%s\n' "$patch_count"
  printf 'kernel_config=projects/ROCKNIX/devices/SM8550/linux/linux.aarch64.conf\n'
  printf 'device_tree_dir=projects/ROCKNIX/devices/SM8550/linux/dts\n'
} > "${work_dir}/.archneo-source-manifest"

mv -- "$work_dir" "$source_dir"
work_dir=""
trap - EXIT INT TERM

archneo_log "prepared ${patch_count} ROCKNIX patches in ${source_dir}"
