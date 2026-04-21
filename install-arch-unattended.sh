#!/usr/bin/env bash

set -euo pipefail

TARGET_DISK="/dev/nvme0n1"
HOSTNAME_VALUE="server"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"
KEYMAP="us"
ROOT_PASSWORD="root"
AUTHORIZED_KEY_FILE=""
REBOOT_AFTER=1

usage() {
  cat <<'EOF'
Unattended Arch install for the QEMU lab VM.

WARNING: This script destroys all data on the target disk.

Run this from the Arch ISO live environment as root.

Usage:
  ./install-arch-unattended.sh [options]

Options:
  --target-disk <path>         Install target disk (default: /dev/nvme0n1)
  --hostname <name>            Hostname (default: server)
  --timezone <zone>            Timezone (default: UTC)
  --root-password <password>   Root password (default: root)
  --authorized-key-file <path> Add SSH pubkey to /root/.ssh/authorized_keys
  --no-reboot                  Do not reboot after install
  -h, --help                   Show this help

What this sets up:
  - GPT + UEFI layout (/boot + /)
  - linux-lts kernel
  - HOOKS in mkinitcpio with kms removed
  - systemd-boot with serial console options
  - systemd-networkd DHCP config for first boot
  - sshd enabled with PermitRootLogin yes
  - Packages needed for ansible bootstrap: neovim bash-completion openssh python
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

partition_path() {
  local disk="$1"
  local part="$2"
  if [[ "$disk" =~ [0-9]$ ]]; then
    printf '%sp%s' "$disk" "$part"
  else
    printf '%s%s' "$disk" "$part"
  fi
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --target-disk)
      TARGET_DISK="$2"
      shift 2
      ;;
    --hostname)
      HOSTNAME_VALUE="$2"
      shift 2
      ;;
    --timezone)
      TIMEZONE="$2"
      shift 2
      ;;
    --root-password)
      ROOT_PASSWORD="$2"
      shift 2
      ;;
    --authorized-key-file)
      AUTHORIZED_KEY_FILE="$2"
      shift 2
      ;;
    --no-reboot)
      REBOOT_AFTER=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

if [[ ! -b "$TARGET_DISK" ]]; then
  echo "Target disk not found: $TARGET_DISK" >&2
  exit 1
fi

if [[ -n "$AUTHORIZED_KEY_FILE" && ! -f "$AUTHORIZED_KEY_FILE" ]]; then
  echo "Authorized key file not found: $AUTHORIZED_KEY_FILE" >&2
  exit 1
fi

require_cmd sgdisk
require_cmd mkfs.fat
require_cmd mkfs.ext4
require_cmd pacstrap
require_cmd arch-chroot
require_cmd genfstab
require_cmd blkid

BOOT_PART="$(partition_path "$TARGET_DISK" 1)"
ROOT_PART="$(partition_path "$TARGET_DISK" 2)"

echo "==> Installing Arch to $TARGET_DISK"
echo "==> Hostname: $HOSTNAME_VALUE"
echo "==> Timezone: $TIMEZONE"

echo "==> Unmounting stale mounts"
umount -R /mnt >/dev/null 2>&1 || true

echo "==> Wiping partition table"
wipefs -af "$TARGET_DISK"
sgdisk --zap-all "$TARGET_DISK"

echo "==> Creating GPT partitions"
sgdisk -n 1:1MiB:+1GiB -t 1:ef00 -c 1:EFI "$TARGET_DISK"
sgdisk -n 2:0:0 -t 2:8304 -c 2:ROOT "$TARGET_DISK"
partprobe "$TARGET_DISK"
sleep 1

echo "==> Formatting filesystems"
mkfs.fat -F32 "$BOOT_PART"
mkfs.ext4 -F "$ROOT_PART"

echo "==> Mounting target"
mount "$ROOT_PART" /mnt
mount --mkdir "$BOOT_PART" /mnt/boot

echo "==> Installing base packages"
pacstrap -K /mnt \
  base \
  linux-lts \
  linux-firmware \
  neovim \
  bash-completion \
  openssh \
  python \
  sudo \
  efibootmgr

echo "==> Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

ROOT_PARTUUID="$(blkid -s PARTUUID -o value "$ROOT_PART")"

echo "==> Configuring installed system"
arch-chroot /mnt /usr/bin/env \
  HOSTNAME_VALUE="$HOSTNAME_VALUE" \
  TIMEZONE="$TIMEZONE" \
  LOCALE="$LOCALE" \
  KEYMAP="$KEYMAP" \
  ROOT_PASSWORD="$ROOT_PASSWORD" \
  ROOT_PARTUUID="$ROOT_PARTUUID" \
  /bin/bash <<'CHROOT'
set -euo pipefail

ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
printf 'LANG=%s\n' "$LOCALE" >/etc/locale.conf
printf 'KEYMAP=%s\n' "$KEYMAP" >/etc/vconsole.conf

printf '%s\n' "$HOSTNAME_VALUE" >/etc/hostname

cat >/etc/systemd/network/01-internal.network <<'EOF_NET'
[Match]
Name=*

[Network]
DHCP=yes
EOF_NET

mkdir -p /etc/systemd/resolved.conf.d
cat >/etc/systemd/resolved.conf.d/dnssec.conf <<'EOF_DNS'
[Resolve]
DNSSEC=no
EOF_DNS

sed -i 's/\<kms\>//g' /etc/mkinitcpio.conf
sed -i 's/  */ /g' /etc/mkinitcpio.conf
mkinitcpio -P

bootctl install

cat >/boot/loader/loader.conf <<'EOF_LOADER'
default arch
timeout 3
console-mode max
editor no
EOF_LOADER

cat >/boot/loader/entries/arch.conf <<EOF_ENTRY
title Arch Linux (linux-lts)
linux /vmlinuz-linux-lts
initrd /initramfs-linux-lts.img
options root=PARTUUID=${ROOT_PARTUUID} rw console=tty1 console=ttyS1,115200n8
EOF_ENTRY

echo "root:${ROOT_PASSWORD}" | chpasswd

if grep -q '^#\?PermitRootLogin' /etc/ssh/sshd_config; then
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
  printf '\nPermitRootLogin yes\n' >>/etc/ssh/sshd_config
fi

if grep -q '^#\?PasswordAuthentication' /etc/ssh/sshd_config; then
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
  printf '\nPasswordAuthentication yes\n' >>/etc/ssh/sshd_config
fi

systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable sshd
CHROOT

if [[ -n "$AUTHORIZED_KEY_FILE" ]]; then
  echo "==> Installing root authorized key"
  install -d -m 700 /mnt/root/.ssh
  install -m 600 "$AUTHORIZED_KEY_FILE" /mnt/root/.ssh/authorized_keys
fi

echo "==> Install complete"
echo "Boot disk: $TARGET_DISK"
echo "Root partition: $ROOT_PART"
echo "Boot partition: $BOOT_PART"

if [[ "$REBOOT_AFTER" -eq 1 ]]; then
  echo "==> Rebooting in 5 seconds (remove installer media if needed)"
  sleep 5
  reboot
else
  echo "==> Not rebooting (--no-reboot)."
  echo "    Run: umount -R /mnt && reboot"
fi
