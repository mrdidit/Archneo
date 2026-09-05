#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources
archneo_load_platform
archneo_load_device

is_sha256() { [[ "$1" =~ ^[0-9a-f]{64}$ ]]; }
is_git_commit() { [[ "$1" =~ ^[0-9a-f]{40}$ ]]; }

validate_device_profile() (
  local expected_id profile="$1"

  unset ARCHNEO_DEVICE_ID ARCHNEO_DEVICE_NAME ARCHNEO_SELECTED_DTB \
    ARCHNEO_BOOT_FS_UUID ARCHNEO_ROOT_FS_UUID ARCHNEO_HOME_FS_UUID \
    ARCHNEO_DISK_GUID ARCHNEO_BOOT_PART_GUID ARCHNEO_ROOT_PART_GUID \
    ARCHNEO_HOME_PART_GUID
  # shellcheck disable=SC1090
  source "$profile"
  expected_id="$(basename -- "$profile" .env)"

  [[ "${ARCHNEO_DEVICE_ID:-}" == "$expected_id" ]] || \
    archneo_die "device profile identity does not match its filename: ${profile}"
  [[ -n "${ARCHNEO_DEVICE_NAME:-}" ]] || \
    archneo_die "device profile has no display name: ${profile}"
  case "$ARCHNEO_DEVICE_ID:$ARCHNEO_SELECTED_DTB" in
    ayaneo-pocket-s-2k:qcs8550-ayaneo-pockets2k.dtb | \
    ayaneo-pocket-evo:qcs8550-ayaneo-pocketevo.dtb)
      ;;
    *)
      archneo_die "unexpected device-tree mapping in ${profile}"
      ;;
  esac
  [[ "$ARCHNEO_BOOT_FS_UUID" =~ ^[0-9A-F]{4}-[0-9A-F]{4}$ ]] || \
    archneo_die "invalid FAT filesystem UUID in ${profile}"
  for filesystem_uuid in "$ARCHNEO_ROOT_FS_UUID" "$ARCHNEO_HOME_FS_UUID"; do
    [[ "$filesystem_uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]] || \
      archneo_die "invalid ext4 filesystem UUID in ${profile}: ${filesystem_uuid}"
  done
  for partition_guid in \
    "$ARCHNEO_DISK_GUID" \
    "$ARCHNEO_BOOT_PART_GUID" \
    "$ARCHNEO_ROOT_PART_GUID" \
    "$ARCHNEO_HOME_PART_GUID"; do
    [[ "$partition_guid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]] || \
      archneo_die "invalid GPT UUID in ${profile}: ${partition_guid}"
  done
  [[ "$ARCHNEO_ROOT_FS_UUID" != "$ARCHNEO_HOME_FS_UUID" ]] || \
    archneo_die "root and home filesystem UUIDs collide in ${profile}"
)

[[ "$ARCHNEO_DEFAULT_DEVICE" == "ayaneo-pocket-evo" ]] || \
  archneo_die "Pocket EVO must remain the active bring-up target"
for device_profile in "${ARCHNEO_PROJECT_ROOT}"/config/devices/*.env; do
  validate_device_profile "$device_profile"
done

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
[[ "$ROCKNIX_ABL_BOOT_PARTITION_NAME" == "system" ]] || \
  archneo_die "removable ABL boot partition must retain the GPT name system"
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
[[ "$ARCHNEO_ROOTFS_SCHEMA" == "7" ]] || \
  archneo_die "rootfs schema must include the USB ACM diagnostic console"
[[ "$ARCHNEO_ROOT_FS_UUID" != "$ARCHNEO_HOME_FS_UUID" ]] || \
  archneo_die "root and home filesystem UUIDs must be different"

[[ ! -e "${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/etc/archneo.conf" ]] || \
  archneo_die "runtime identity must be generated from the selected device profile"
grep -Fq "printf 'ARCHNEO_HOME_FS_UUID=%q" \
  "${ARCHNEO_PROJECT_ROOT}/scripts/prepare-rootfs.sh" || \
  archneo_die "rootfs builder does not write the selected home UUID"

for config_line in \
  'CONFIG_INITRAMFS_SOURCE=""' \
  'CONFIG_DEFAULT_HOSTNAME="archneo"' \
  'CONFIG_LOCALVERSION="-archneo"' \
  '# CONFIG_LOCALVERSION_AUTO is not set' \
  'CONFIG_DEVTMPFS=y' \
  'CONFIG_DEVTMPFS_MOUNT=y' \
  'CONFIG_MMC=y' \
  'CONFIG_MMC_BLOCK=y' \
  'CONFIG_MMC_SDHCI=y' \
  'CONFIG_MMC_SDHCI_MSM=y' \
  'CONFIG_EXT4_FS=y'; do
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

configure_rootfs="${ARCHNEO_PROJECT_ROOT}/scripts/configure-rootfs.sh"
for required_rootfs_line in \
  '  networkmanager \' \
  '  mkinitcpio \' \
  '  wpa_supplicant' \
  'systemctl set-default multi-user.target' \
  '  NetworkManager.service \' \
  '  getty@tty1.service'; do
  grep -Fxq "$required_rootfs_line" "$configure_rootfs" || \
    archneo_die "missing console/network rootfs policy: ${required_rootfs_line}"
done
grep -Fq 'systemd-networkd.service' "$configure_rootfs" || \
  archneo_die "systemd-networkd is not disabled before enabling NetworkManager"

firstboot="${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/usr/local/sbin/archneo-firstboot"
grep -Fxq 'until passwd root; do' "$firstboot" || \
  archneo_die "first-boot setup does not require a root password"
grep -Fxq 'until passwd deck; do' "$firstboot" || \
  archneo_die "first-boot setup does not require a deck password"

[[ ! -e "${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/etc/pacman.conf" ]] || \
  archneo_die "Archneo must retain the official Arch Linux ARM pacman.conf"

package_kernel="${ARCHNEO_PROJECT_ROOT}/scripts/package-kernel.sh"
grep -Fq 'root=PARTUUID=${ARCHNEO_ROOT_PART_GUID}' "$package_kernel" || \
  archneo_die "direct-root KERNEL does not use the root GPT UUID"
grep -Fq 'md5sum KERNEL > KERNEL.md5' "$package_kernel" || \
  archneo_die "ABL KERNEL.md5 is not generated"
grep -Fq -- "-name 'qcs8550-*.dts'" "$package_kernel" || \
  archneo_die "the complete ROCKNIX SM8550 DTB set is not packaged"
grep -Fq 'usb_diagnostic="cdc-acm:ttyGS0"' "$package_kernel" || \
  archneo_die "diagnostic KERNEL does not record its USB ACM console"
grep -Fq 'usb_console_argument="console=ttyGS0,115200n8"' "$package_kernel" || \
  archneo_die "diagnostic KERNEL does not select ttyGS0"

embed_initramfs="${ARCHNEO_PROJECT_ROOT}/scripts/embed-initramfs.sh"
for usb_console_setting in USB_CONFIGFS_ACM U_SERIAL_CONSOLE; do
  grep -Fq -- "--enable ${usb_console_setting}" "$embed_initramfs" || \
    archneo_die "diagnostic kernel does not enable ${usb_console_setting}"
done

diagnostic_hook="${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/etc/initcpio/hooks/archneo-diagnostics"
grep -Fq 'archneo_diag_setup_usb_acm' "$diagnostic_hook" || \
  archneo_die "initramfs hook does not configure USB ACM"
grep -Fq 'Archneo Early Boot Console' "$diagnostic_hook" || \
  archneo_die "USB ACM diagnostic product identity is missing"

usb_firstboot_override="${ARCHNEO_PROJECT_ROOT}/rootfs-overlay/usr/share/archneo/diagnostics/firstboot-usb-console.conf"
grep -Fxq 'TTYPath=/dev/ttyGS0' "$usb_firstboot_override" || \
  archneo_die "diagnostic first-boot setup is not routed to ttyGS0"

build_image="${ARCHNEO_PROJECT_ROOT}/scripts/build-image.sh"
grep -Fq -- '--change-name=1:"$ROCKNIX_ABL_BOOT_PARTITION_NAME"' "$build_image" || \
  archneo_die "removable image does not use the ABL GPT partition name"
grep -Fq 'ARCHNEO_EARLY_BOOT_DIAGNOSTICS' "$build_image" || \
  archneo_die "image builder has no early-boot diagnostic mode"
grep -Fq 'initramfs-linux-archneo.cpio.gz' "$build_image" || \
  archneo_die "diagnostic initramfs is not copied to the inspection filesystem"

workflow="${ARCHNEO_PROJECT_ROOT}/.github/workflows/kernel.yml"
grep -Fq 'ARCHNEO_EARLY_BOOT_DIAGNOSTICS: "1"' "$workflow" || \
  archneo_die "Pocket EVO workflow does not build the early-boot diagnostic image"

archneo_log "repository verification passed"
