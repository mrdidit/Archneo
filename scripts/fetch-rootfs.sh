#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
archneo_load_sources

for command in curl gpg sha256sum; do
  archneo_need_command "$command"
done

downloads="${ARCHNEO_CACHE_DIR}/downloads"
rootfs="${downloads}/ArchLinuxARM-aarch64-latest.tar.gz"
signature="${rootfs}.sig"
keyring="${downloads}/archlinuxarm-${ARCHLINUXARM_KEYRING_COMMIT}.gpg"
signature_status="${ARCHNEO_BUILD_DIR}/archlinuxarm-rootfs-signature.status"
gnupg_home="${ARCHNEO_BUILD_DIR}/archlinuxarm-gnupg"

mkdir -p -- "$downloads" "$ARCHNEO_BUILD_DIR" "$gnupg_home"
chmod 0700 "$gnupg_home"

archneo_fetch_https \
  "$ARCHLINUXARM_KEYRING_URL" \
  "$ARCHLINUXARM_KEYRING_SHA256" \
  "$keyring"

fetch_moving_file() {
  local url="$1"
  local destination="$2"
  local partial="${destination}.part"

  # Arch Linux ARM's official rootfs service redirects to HTTP mirrors and its
  # certificate does not cover os.archlinuxarm.org. Transport is therefore not
  # the authenticity boundary: the detached signature and pinned HTTPS-fetched
  # keyring below are mandatory. Refuse arbitrary unsigned HTTP locations.
  [[ "$url" == "$ARCHLINUXARM_ROOTFS_URL" || \
    "$url" == "$ARCHLINUXARM_ROOTFS_SIGNATURE_URL" ]] || \
    archneo_die "refusing unexpected Arch Linux ARM rootfs URL: ${url}"
  if [[ -f "$destination" ]]; then
    archneo_log "using cached Arch Linux ARM snapshot file: ${destination}"
    return
  fi

  archneo_log "fetching ${url}"
  curl --fail --location --proto '=http,https' --proto-redir '=http,https' \
    --output "$partial" -- "$url"
  mv -- "$partial" "$destination"
}

fetch_moving_file "$ARCHLINUXARM_ROOTFS_URL" "$rootfs"
fetch_moving_file "$ARCHLINUXARM_ROOTFS_SIGNATURE_URL" "$signature"

GNUPGHOME="$gnupg_home" gpg --batch --quiet --import "$keyring"
if ! GNUPGHOME="$gnupg_home" gpg --batch --status-fd 1 \
  --verify "$signature" "$rootfs" > "$signature_status"; then
  archneo_die "Arch Linux ARM rootfs signature verification failed"
fi

if ! awk -v expected="$ARCHLINUXARM_SIGNING_FINGERPRINT" '
  $1 == "[GNUPG:]" && $2 == "VALIDSIG" && ($3 == expected || $NF == expected) {
    found = 1
  }
  END { exit(found ? 0 : 1) }
' "$signature_status"; then
  archneo_die "rootfs signature was not made by the pinned Arch Linux ARM key"
fi

sha256sum -- "$rootfs" > "${rootfs}.sha256"
archneo_log "verified Arch Linux ARM rootfs snapshot: ${rootfs}"
