#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources

archneo_need_command git

destination="${ARCHNEO_CACHE_DIR}/rocknix-distribution"

if [[ ! -e "$destination" ]]; then
  mkdir -p -- "$(dirname -- "$destination")"
  archneo_log "cloning ROCKNIX distribution metadata"
  git clone --filter=blob:none --no-checkout \
    "$ROCKNIX_DISTRIBUTION_URL" "$destination"
  git -C "$destination" sparse-checkout set \
    projects/ROCKNIX/packages/linux \
    projects/ROCKNIX/devices/SM8550
else
  [[ -d "${destination}/.git" ]] || \
    archneo_die "cache path exists but is not a Git checkout: ${destination}"
  [[ -z "$(git -C "$destination" status --porcelain)" ]] || \
    archneo_die "refusing to change dirty ROCKNIX cache: ${destination}"
  origin="$(git -C "$destination" remote get-url origin)"
  [[ "$origin" == "$ROCKNIX_DISTRIBUTION_URL" ]] || \
    archneo_die "unexpected ROCKNIX origin: ${origin}"
fi

if ! git -C "$destination" cat-file -e "${ROCKNIX_DISTRIBUTION_COMMIT}^{commit}" 2>/dev/null; then
  archneo_log "fetching ROCKNIX ${ROCKNIX_DISTRIBUTION_COMMIT}"
  git -C "$destination" fetch --depth=1 origin "$ROCKNIX_DISTRIBUTION_COMMIT"
else
  archneo_log "using cached ROCKNIX commit ${ROCKNIX_DISTRIBUTION_COMMIT}"
fi
git -C "$destination" checkout --detach "$ROCKNIX_DISTRIBUTION_COMMIT"

actual="$(git -C "$destination" rev-parse HEAD)"
[[ "$actual" == "$ROCKNIX_DISTRIBUTION_COMMIT" ]] || \
  archneo_die "ROCKNIX checkout mismatch: ${actual}"

archneo_log "ROCKNIX source ready at ${destination}"
