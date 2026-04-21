#!/usr/bin/env bash

set -euo pipefail

SECRETS_FILE="vars/secrets.fake.yml"
PLAYBOOK="play-server.yml"
SSH_HOST="127.0.0.1"
SSH_PORT="2222"
SSH_USER="arch"
SSH_KEY="/tmp/ansible-qemu"
BECOME_PASSWORD="arch"
BOOTSTRAP_OLD_LTS=1
LTS_VERSION=""

usage() {
  cat <<'EOF'
Run play-server.yml against a QEMU VM using a selected secrets file.

Usage:
  ./apply-server-qemu.sh [options] [-- <additional ansible-playbook args>]

Options:
  --secrets-file <path>     Source secrets yaml (default: vars/secrets.fake.yml)
  --playbook <path>         Playbook path (default: play-server.yml)
  --ssh-host <host>         VM host/IP (default: 127.0.0.1)
  --ssh-port <port>         VM SSH forwarded port (default: 2222)
  --ssh-user <user>         SSH user (default: arch)
  --ssh-key <path>          SSH private key path (default: /tmp/ansible-qemu)
  --become-password <pass>  sudo password for SSH user (default: arch)
  --no-bootstrap-old-lts    Skip installing pinned older linux-lts package
  --lts-version <version>   linux-lts version for bootstrap (auto-detect from zfs-linux-lts by default)
  -h, --help                Show this help

This script temporarily installs the selected secrets file as vars/secrets.yml,
runs ansible-playbook, then restores the previous vars/secrets.yml if one existed.
EOF
}

EXTRA_ARGS=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --secrets-file)
      SECRETS_FILE="$2"
      shift 2
      ;;
    --playbook)
      PLAYBOOK="$2"
      shift 2
      ;;
    --ssh-host)
      SSH_HOST="$2"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT="$2"
      shift 2
      ;;
    --ssh-user)
      SSH_USER="$2"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY="$2"
      shift 2
      ;;
    --become-password)
      BECOME_PASSWORD="$2"
      shift 2
      ;;
    --no-bootstrap-old-lts)
      BOOTSTRAP_OLD_LTS=0
      shift
      ;;
    --lts-version)
      LTS_VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_ARGS=("$@")
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Secrets file not found: $SECRETS_FILE" >&2
  exit 1
fi

if [[ ! -f "$PLAYBOOK" ]]; then
  echo "Playbook not found: $PLAYBOOK" >&2
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  echo "SSH private key not found: $SSH_KEY" >&2
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Missing required command: ansible-playbook" >&2
  exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
  echo "Missing required command: ssh" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_SECRETS="${SCRIPT_DIR}/vars/secrets.yml"
BACKUP_SECRETS=""
INVENTORY_FILE="$(mktemp)"
KNOWN_HOSTS_FILE="$(mktemp)"

cleanup() {
  rm -f "$INVENTORY_FILE"
  rm -f "$KNOWN_HOSTS_FILE"
  if [[ -n "$BACKUP_SECRETS" && -f "$BACKUP_SECRETS" ]]; then
    mv "$BACKUP_SECRETS" "$TARGET_SECRETS"
  else
    rm -f "$TARGET_SECRETS"
  fi
}
trap cleanup EXIT

if [[ -f "$TARGET_SECRETS" ]]; then
  BACKUP_SECRETS="$(mktemp)"
  cp "$TARGET_SECRETS" "$BACKUP_SECRETS"
fi

cp "$SECRETS_FILE" "$TARGET_SECRETS"
chmod 600 "$TARGET_SECRETS"

cat >"$INVENTORY_FILE" <<EOF
[server]
server ansible_host=${SSH_HOST} ansible_port=${SSH_PORT} ansible_user=${SSH_USER} ansible_ssh_private_key_file=${SSH_KEY} ansible_become=true ansible_become_method=sudo ansible_become_password=${BECOME_PASSWORD}
EOF

SSH_OPTS=(
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile="$KNOWN_HOSTS_FILE"
  -p "$SSH_PORT"
)

run_ssh() {
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SSH_HOST}" "$@"
}

echo "==> Bootstrap: ensure python is available"
run_ssh "sudo pacman -Sy --noconfirm --needed python"

echo "==> Bootstrap: enable serial console for debugging"
run_ssh "sudo bash -s" <<'EOF'
set -euo pipefail

if ! grep -q "console=ttyS0,115200n8" /etc/default/grub; then
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 console=tty1 console=ttyS0,115200n8"/' /etc/default/grub
fi

if grep -q '^GRUB_TERMINAL=' /etc/default/grub; then
  sed -i 's/^GRUB_TERMINAL=.*/GRUB_TERMINAL="console serial"/' /etc/default/grub
else
  echo 'GRUB_TERMINAL="console serial"' >> /etc/default/grub
fi

if ! grep -q '^GRUB_SERIAL_COMMAND=' /etc/default/grub; then
  echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
fi

grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable serial-getty@ttyS0.service
EOF

echo "==> Bootstrap: disable arch-box default DHCP network unit"
run_ssh "if [ -e /etc/systemd/network/80-dhcp.network ]; then sudo ln -sf /dev/null /etc/systemd/network/80-dhcp.network; fi"

if [[ "$BOOTSTRAP_OLD_LTS" -eq 1 ]]; then
  if [[ -z "$LTS_VERSION" ]]; then
    LTS_VERSION="$(run_ssh "sudo pacman -Si zfs-linux-lts 2>/dev/null | sed -n 's/.*linux-lts=\\([^ ]*\\).*/\\1/p; q'")"
  fi

  if [[ -z "$LTS_VERSION" ]]; then
    echo "==> Bootstrap: could not detect zfs-linux-lts kernel pin yet; skipping LTS archive bootstrap"
    echo "    (this is expected on first boot before archzfs repo is configured)"
  else
    LTS_PKG="https://archive.archlinux.org/packages/l/linux-lts/linux-lts-${LTS_VERSION}-x86_64.pkg.tar.zst"
    LTS_HEADERS_PKG="https://archive.archlinux.org/packages/l/linux-lts-headers/linux-lts-headers-${LTS_VERSION}-x86_64.pkg.tar.zst"
    echo "==> Bootstrap: install linux-lts ${LTS_VERSION} from Arch Archive"
    run_ssh \
      "sudo pacman -U --noconfirm --needed '${LTS_PKG}' '${LTS_HEADERS_PKG}'"
  fi
fi

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "$INVENTORY_FILE" --extra-vars "@${TARGET_SECRETS}" "$PLAYBOOK" "${EXTRA_ARGS[@]}"
