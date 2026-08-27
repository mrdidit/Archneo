#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources

downloads="${ARCHNEO_CACHE_DIR}/downloads"
mkdir -p -- "$downloads"

archneo_fetch_https \
  "$ROCKNIX_EXTRA_FIRMWARE_ARCHIVE_URL" \
  "$ROCKNIX_EXTRA_FIRMWARE_ARCHIVE_SHA256" \
  "${downloads}/rocknix-extra-firmware-${ROCKNIX_EXTRA_FIRMWARE_COMMIT}.tar.gz"

archneo_log "ROCKNIX SM8550 firmware archive is present and checksum-verified"
