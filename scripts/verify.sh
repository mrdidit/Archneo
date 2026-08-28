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
is_git_commit "$ARCHLINUXARM_KEYRING_COMMIT" || \
  archneo_die "ARCHLINUXARM_KEYRING_COMMIT is not a full Git revision"

for checksum in \
  "$LINUX_SHA256" \
  "$MKBOOTIMG_SHA256" \
  "$ROCKNIX_ABL_RELEASE_SHA256" \
  "$ARCHLINUXARM_KEYRING_SHA256" \
  "$ROCKNIX_EXTRA_FIRMWARE_ARCHIVE_SHA256"; do
  is_sha256 "$checksum" || archneo_die "invalid SHA-256 value: ${checksum}"
done

[[ "$ARCHLINUXARM_SIGNING_FINGERPRINT" =~ ^[0-9A-F]{40}$ ]] || \
  archneo_die "invalid Arch Linux ARM signing fingerprint"
[[ "$ARCHLINUXARM_ROOTFS_URL" == \
  "http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz" ]] || \
  archneo_die "unexpected Arch Linux ARM rootfs URL"
[[ "$ARCHLINUXARM_ROOTFS_SIGNATURE_URL" == "${ARCHLINUXARM_ROOTFS_URL}.sig" ]] || \
  archneo_die "unexpected Arch Linux ARM rootfs signature URL"
for secure_url in \
  "$ARCHLINUXARM_KEYRING_URL" \
  "$LINUX_URL" \
  "$MKBOOTIMG_URL" \
  "$ROCKNIX_EXTRA_FIRMWARE_ARCHIVE_URL"; do
  [[ "$secure_url" == https://* ]] || archneo_die "source must use HTTPS: ${secure_url}"
done
[[ "$ROCKNIX_ABL_BOOT_LABEL" == "ROCKNIX" ]] || \
  archneo_die "ROCKNIX_ABL_BOOT_LABEL must remain ROCKNIX for ABL compatibility"
[[ "$ARCHNEO_ROOT_LABEL" =~ ^[A-Z0-9_]{1,16}$ ]] || \
  archneo_die "invalid ext4 root label: ${ARCHNEO_ROOT_LABEL}"
[[ "$ARCHNEO_HOME_LABEL" =~ ^[A-Z0-9_]{1,16}$ ]] || \
  archneo_die "invalid ext4 home label: ${ARCHNEO_HOME_LABEL}"
[[ "$ARCHNEO_BOOT_FS_UUID" =~ ^[0-9A-F]{4}-[0-9A-F]{4}$ ]] || \
  archneo_die "invalid FAT filesystem UUID"
for filesystem_uuid in "$ARCHNEO_ROOT_FS_UUID" "$ARCHNEO_HOME_FS_UUID"; do
  [[ "$filesystem_uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]] || \
    archneo_die "invalid ext4 filesystem UUID: ${filesystem_uuid}"
done
for partition_guid in \
  "$ARCHNEO_DISK_GUID" \
  "$ARCHNEO_BOOT_PART_GUID" \
  "$ARCHNEO_ROOT_PART_GUID" \
  "$ARCHNEO_HOME_PART_GUID"; do
  [[ "$partition_guid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]] || \
    archneo_die "invalid GPT UUID: ${partition_guid}"
done
[[ "$ABL_SYSTEM_PART_START_SECTORS" == "32768" ]] || \
  archneo_die "ABL system partition start must remain at sector 32768"
[[ "$ABL_SYSTEM_PART_SIZE_MIB" == "2048" ]] || \
  archneo_die "ABL system partition size must remain 2048 MiB"
[[ "$ARCHNEO_ROOT_SIZE_MIB" == "30720" ]] || \
  archneo_die "removable-image root partition must remain 30 GiB"
[[ "$ARCHNEO_HOME_SEED_SIZE_MIB" =~ ^[1-9][0-9]*$ ]] || \
  archneo_die "home seed size must be a positive MiB value"
[[ "$ARCHNEO_ROOTFS_SCHEMA" =~ ^[1-9][0-9]*$ ]] || \
  archneo_die "rootfs schema must be a positive integer"
[[ "$ARCHNEO_ROOT_FS_UUID" != "$ARCHNEO_HOME_FS_UUID" ]] || \
  archneo_die "root and home filesystem UUIDs must be different"

grep -Fxq "ARCHNEO_HOME_FS_UUID=\"${ARCHNEO_HOME_FS_UUID}\"" \
  "${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/etc/archneo.conf" || \
  archneo_die "runtime home UUID disagrees with platform.env"

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
  [[ -x "$script" ]] || archneo_die "script is not executable: ${script}"
done < <(
  find \
    "${ARCHNEO_PROJECT_ROOT}/scripts" \
    "${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/usr/local/sbin" \
    -type f | LC_ALL=C sort
)

while IFS= read -r initcpio_hook; do
  bash -n "$initcpio_hook"
done < <(
  find "${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/etc/initcpio" -type f | LC_ALL=C sort
)

grep -Eq '^HOOKS=.*archneo-diagnostics' \
  "${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/etc/mkinitcpio.conf.d/archneo.conf" || \
  archneo_die "Archneo initramfs diagnostics hook is not enabled"

archneo_log "repository verification passed"
