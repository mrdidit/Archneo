#!/usr/bin/env bash

# This script executes inside the aarch64 staging root under qemu/binfmt.
set -euo pipefail

kernel_release="${1:?kernel release is required}"
[[ -d "/usr/lib/modules/${kernel_release}" ]] || {
  printf 'archneo: custom kernel modules are missing: %s\n' "$kernel_release" >&2
  exit 1
}

cleanup_build_agents() {
  if command -v gpgconf >/dev/null 2>&1; then
    GNUPGHOME=/etc/pacman.d/gnupg gpgconf --kill all >/dev/null 2>&1 || true
  fi
}
trap cleanup_build_agents EXIT

cache_mount="$(findmnt -nro TARGET --target /var/cache/pacman/pkg || true)"
[[ -n "$cache_mount" ]] || {
  printf 'archneo: pacman cache has no chroot-visible mount point\n' >&2
  exit 1
}
printf 'archneo: pacman cache mount: %s\n' "$cache_mount"
df -Pk /var/cache/pacman/pkg

pacman-key --init
pacman-key --populate archlinuxarm

if pacman -Qq linux-aarch64 >/dev/null 2>&1; then
  # Remove the generic kernel before the rolling update so it is not upgraded,
  # does not regenerate an irrelevant initramfs, and cannot own /boot.
  pacman -Rdd --noconfirm linux-aarch64
fi

# Pacman 7 uses Landlock/seccomp for its downloader. Those kernel interfaces
# are not available through qemu-user on the x86 build host, so disable the
# sandbox for this emulated transaction only. The installed pacman.conf keeps
# its normal sandbox policy.
pacman -Syu --disable-sandbox --needed --noconfirm \
  bash \
  e2fsprogs \
  linux-firmware \
  mkinitcpio \
  parted \
  sudo \
  systemd \
  util-linux

if getent passwd alarm >/dev/null; then
  userdel --remove alarm
fi
if getent group alarm >/dev/null; then
  groupdel alarm
fi
if getent group 1000 >/dev/null; then
  printf 'archneo: GID 1000 remains occupied after removing alarm\n' >&2
  exit 1
fi

groupadd --gid 1000 deck
useradd \
  --uid 1000 \
  --gid 1000 \
  --groups wheel \
  --create-home \
  --shell /bin/bash \
  deck

passwd --lock root
passwd --lock deck

chmod 0440 /etc/sudoers.d/10-archneo-wheel
chmod 0755 /usr/local/sbin/archneo-firstboot /usr/local/sbin/archneo-grow-home
systemctl disable sshd.service >/dev/null 2>&1 || true
systemctl enable archneo-firstboot.service archneo-grow-home.service

find /boot -mindepth 1 -maxdepth 1 -delete

install -d -m 0755 /usr/share/archneo /var/lib/archneo /var/log/journal
pacman -Q > /usr/share/archneo/packages.txt
pacman -Scc --noconfirm

# Let systemd create unique identities and random state on the target.
: > /etc/machine-id
find /var/lib/systemd/random-seed -maxdepth 0 -type f -delete 2>/dev/null || true

cleanup_build_agents
trap - EXIT
