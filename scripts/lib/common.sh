#!/usr/bin/env bash

set -euo pipefail

ARCHNEO_PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
ARCHNEO_CACHE_DIR="${ARCHNEO_CACHE_DIR:-${ARCHNEO_PROJECT_ROOT}/.cache}"
# The kernel build system rejects source/output paths containing spaces. Use a
# persistent per-user cache outside the repository so a spaced workspace path
# works and multi-day builds survive reboots and /tmp cleanup.
if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
  ARCHNEO_USER_CACHE_BASE="$XDG_CACHE_HOME"
else
  ARCHNEO_USER_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
  [[ -n "$ARCHNEO_USER_HOME" ]] || {
    printf 'archneo: error: unable to determine the current user home\n' >&2
    exit 1
  }
  ARCHNEO_USER_CACHE_BASE="${ARCHNEO_USER_HOME}/.cache"
fi
ARCHNEO_STATE_DIR="${ARCHNEO_STATE_DIR:-${ARCHNEO_USER_CACHE_BASE}/archneo}"
ARCHNEO_BUILD_DIR="${ARCHNEO_BUILD_DIR:-${ARCHNEO_STATE_DIR}/build}"
ARCHNEO_OUT_DIR="${ARCHNEO_OUT_DIR:-${ARCHNEO_PROJECT_ROOT}/out}"

if [[ "$ARCHNEO_BUILD_DIR" == *[[:space:]:]* ]]; then
  printf 'archneo: error: ARCHNEO_BUILD_DIR cannot contain spaces or colons: %s\n' \
    "$ARCHNEO_BUILD_DIR" >&2
  exit 1
fi

archneo_log() {
  printf 'archneo: %s\n' "$*"
}

archneo_die() {
  printf 'archneo: error: %s\n' "$*" >&2
  exit 1
}

archneo_need_command() {
  command -v "$1" >/dev/null 2>&1 || archneo_die "required command not found: $1"
}

archneo_load_sources() {
  # shellcheck disable=SC1091
  source "${ARCHNEO_PROJECT_ROOT}/config/sources.env"
}

archneo_load_platform() {
  # shellcheck disable=SC1091
  source "${ARCHNEO_PROJECT_ROOT}/config/platform.env"
}

archneo_verify_sha256() {
  local expected="$1"
  local file="$2"
  local actual

  actual="$(sha256sum -- "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || \
    archneo_die "SHA-256 mismatch for ${file}: expected ${expected}, got ${actual}"
}

archneo_fetch_https() {
  local url="$1"
  local expected_sha256="$2"
  local destination="$3"
  local partial="${destination}.part"

  [[ "$url" == https://* ]] || archneo_die "refusing non-HTTPS archive URL: ${url}"
  mkdir -p -- "$(dirname -- "$destination")"

  if [[ -f "$destination" ]]; then
    archneo_verify_sha256 "$expected_sha256" "$destination"
    archneo_log "using verified cache: ${destination}"
    return
  fi

  archneo_need_command curl
  archneo_log "fetching ${url}"
  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "$partial" -- "$url"
  archneo_verify_sha256 "$expected_sha256" "$partial"
  mv -- "$partial" "$destination"
}
