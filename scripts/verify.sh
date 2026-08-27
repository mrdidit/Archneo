#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources
archneo_load_platform

is_sha256() { [[ "$1" =~ ^[0-9a-f]{64}$ ]]; }
is_git_commit() { [[ "$1" =~ ^[0-9a-f]{40}$ ]]; }

is_git_commit "$ROCKNIX_DISTRIBUTION_COMMIT" || \
  archneo_die "ROCKNIX_DISTRIBUTION_COMMIT is not a full Git revision"
is_git_commit "$MKBOOTIMG_VERSION" || \
  archneo_die "MKBOOTIMG_VERSION is not a full Git revision"
is_git_commit "$ROCKNIX_ABL_LINUXLOADER_COMMIT" || \
  archneo_die "ROCKNIX_ABL_LINUXLOADER_COMMIT is not a full Git revision"
is_git_commit "$ROCKNIX_EXTRA_FIRMWARE_COMMIT" || \
  archneo_die "ROCKNIX_EXTRA_FIRMWARE_COMMIT is not a full Git revision"

for checksum in \
  "$LINUX_SHA256" \
  "$MKBOOTIMG_SHA256" \
  "$ROCKNIX_ABL_RELEASE_SHA256" \
  "$LINUX_FIRMWARE_SHA256" \
  "$ROCKNIX_EXTRA_FIRMWARE_ARCHIVE_SHA256"; do
  is_sha256 "$checksum" || archneo_die "invalid SHA-256 value: ${checksum}"
done

[[ "$ARCHLINUXARM_SIGNING_FINGERPRINT" =~ ^[0-9A-F]{40}$ ]] || \
  archneo_die "invalid Arch Linux ARM signing fingerprint"
[[ "$ROCKNIX_ABL_BOOT_LABEL" == "ROCKNIX" ]] || \
  archneo_die "ROCKNIX_ABL_BOOT_LABEL must remain ROCKNIX for ABL compatibility"
[[ "$ARCHNEO_ROOT_LABEL" =~ ^[A-Z0-9_]{1,16}$ ]] || \
  archneo_die "invalid ext4 root label: ${ARCHNEO_ROOT_LABEL}"
[[ "$ABL_SYSTEM_PART_START_SECTORS" == "32768" ]] || \
  archneo_die "ABL system partition start must remain at sector 32768"
[[ "$ABL_SYSTEM_PART_SIZE_MIB" == "2048" ]] || \
  archneo_die "ABL system partition size must remain 2048 MiB"

for config_line in \
  'CONFIG_INITRAMFS_SOURCE=""' \
  'CONFIG_DEFAULT_HOSTNAME="archneo"' \
  'CONFIG_LOCALVERSION="-archneo"' \
  '# CONFIG_LOCALVERSION_AUTO is not set'; do
  grep -Fxq "$config_line" \
    "${ARCHNEO_PROJECT_ROOT}/config/kernel/archneo-sm8550.fragment" || \
    archneo_die "missing kernel fragment setting: ${config_line}"
done

while IFS= read -r script; do
  bash -n "$script"
done < <(find "${ARCHNEO_PROJECT_ROOT}/scripts" -type f -name '*.sh' | LC_ALL=C sort)

archneo_log "repository verification passed"
