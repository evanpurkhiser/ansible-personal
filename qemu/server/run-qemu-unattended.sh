#!/usr/bin/env bash

set -euo pipefail

NAME="arch-server-lab"
VM_DIR="${HOME}/vms/${NAME}"
RAM_MB=8192
CPUS=4
BOOT_DISK_SIZE="64G"
DATA_DISK_COUNT=5
DATA_DISK_SIZE="4T"
SSH_PORT=2222

TARGET_DISK="/dev/nvme0n1"
HOSTNAME_VALUE="server"
TIMEZONE="UTC"
ROOT_PASSWORD="root"
AUTHORIZED_KEY_FILE=""

HTTP_PORT=8012

usage() {
  cat <<'EOF'
Run a mostly unattended Arch install in QEMU, then boot into installed system.

Usage:
  qemu/server/run-qemu-unattended.sh [options]

QEMU options:
  --name <name>             VM name (default: arch-server-lab)
  --vm-dir <path>           VM directory (default: ~/vms/<name>)
  --ram <mb>                Memory in MB (default: 8192)
  --cpus <count>            vCPU count (default: 4)
  --boot-disk-size <size>   Boot disk size (default: 64G)
  --data-disk-count <n>     Number of data disks (default: 5)
  --data-disk-size <size>   Data disk size (default: 4T)
  --ssh-port <port>         Host forwarded SSH port (default: 2222)

Installer options:
  --target-disk <path>         Install target disk (default: /dev/nvme0n1)
  --hostname <name>            Hostname (default: server)
  --timezone <zone>            Timezone (default: UTC)
  --root-password <password>   Root password (default: root)
  --authorized-key-file <path> Root authorized key for installed system

Other:
  --http-port <port>        Temporary host HTTP port (default: 8012)
  -h, --help                Show this help

Notes:
  - Requires: expect, python, curl, qemu-system-x86_64, qemu-img.
  - Runs installer boot headless, executes install script from live environment,
    powers off, then reboots from disk and keeps VM attached to this terminal.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --vm-dir) VM_DIR="$2"; shift 2 ;;
    --ram) RAM_MB="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --boot-disk-size) BOOT_DISK_SIZE="$2"; shift 2 ;;
    --data-disk-count) DATA_DISK_COUNT="$2"; shift 2 ;;
    --data-disk-size) DATA_DISK_SIZE="$2"; shift 2 ;;
    --ssh-port) SSH_PORT="$2"; shift 2 ;;
    --target-disk) TARGET_DISK="$2"; shift 2 ;;
    --hostname) HOSTNAME_VALUE="$2"; shift 2 ;;
    --timezone) TIMEZONE="$2"; shift 2 ;;
    --root-password) ROOT_PASSWORD="$2"; shift 2 ;;
    --authorized-key-file) AUTHORIZED_KEY_FILE="$2"; shift 2 ;;
    --http-port) HTTP_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd expect
require_cmd python
require_cmd curl
require_cmd qemu-system-x86_64
require_cmd qemu-img

if [ -n "$AUTHORIZED_KEY_FILE" ] && [ ! -f "$AUTHORIZED_KEY_FILE" ]; then
  echo "Authorized key file not found: $AUTHORIZED_KEY_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGE_DIR="$(mktemp -d)"
HTTP_PID=""

cleanup() {
  if [ -n "$HTTP_PID" ] && kill -0 "$HTTP_PID" >/dev/null 2>&1; then
    kill "$HTTP_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

cp "${SCRIPT_DIR}/install-arch-unattended.sh" "${STAGE_DIR}/install-arch-unattended.sh"
chmod 755 "${STAGE_DIR}/install-arch-unattended.sh"

if [ -n "$AUTHORIZED_KEY_FILE" ]; then
  cp "$AUTHORIZED_KEY_FILE" "${STAGE_DIR}/authorized_key.pub"
fi

python -m http.server "$HTTP_PORT" --bind 127.0.0.1 --directory "$STAGE_DIR" >/tmp/run-qemu-http.log 2>&1 &
HTTP_PID="$!"

echo "==> Starting installer boot and unattended install"

EXPECT_SCRIPT="$(mktemp)"
cat >"$EXPECT_SCRIPT" <<'EOF_EXPECT'
set timeout -1

set n [llength $argv]
set http_port [lindex $argv [expr {$n-6}]]
set target_disk [lindex $argv [expr {$n-5}]]
set hostname_value [lindex $argv [expr {$n-4}]]
set timezone [lindex $argv [expr {$n-3}]]
set root_password [lindex $argv [expr {$n-2}]]
set has_key [lindex $argv [expr {$n-1}]]
set boot_cmd [lrange $argv 0 [expr {$n-7}]]

spawn {*}$boot_cmd

expect {
  -re {root@archiso.*# $} {}
  -re {archiso login:} {
    send -- "root\r"
    exp_continue
  }
}

send -- "curl -fsSL http://10.0.2.2:${http_port}/install-arch-unattended.sh -o /root/install-arch-unattended.sh\r"
expect -re {root@archiso.*# $}
send -- "chmod +x /root/install-arch-unattended.sh\r"
expect -re {root@archiso.*# $}

if {$has_key eq "1"} {
  send -- "curl -fsSL http://10.0.2.2:${http_port}/authorized_key.pub -o /root/authorized_key.pub\r"
  expect -re {root@archiso.*# $}
  send -- "/root/install-arch-unattended.sh --target-disk ${target_disk} --hostname ${hostname_value} --timezone ${timezone} --root-password ${root_password} --authorized-key-file /root/authorized_key.pub --no-reboot\r"
} else {
  send -- "/root/install-arch-unattended.sh --target-disk ${target_disk} --hostname ${hostname_value} --timezone ${timezone} --root-password ${root_password} --no-reboot\r"
}

expect -re {==> Install complete}
expect -re {root@archiso.*# $}

send -- "umount -R /mnt || true\r"
expect -re {root@archiso.*# $}
send -- "poweroff\r"

expect {
  eof {}
}
EOF_EXPECT

expect "$EXPECT_SCRIPT" \
  "${SCRIPT_DIR}/boot-qemu.sh" \
  --name "$NAME" \
  --vm-dir "$VM_DIR" \
  --ram "$RAM_MB" \
  --cpus "$CPUS" \
  --boot-disk-size "$BOOT_DISK_SIZE" \
  --data-disk-count "$DATA_DISK_COUNT" \
  --data-disk-size "$DATA_DISK_SIZE" \
  --ssh-port "$SSH_PORT" \
  "$HTTP_PORT" "$TARGET_DISK" "$HOSTNAME_VALUE" "$TIMEZONE" "$ROOT_PASSWORD" \
  "$( [ -n "$AUTHORIZED_KEY_FILE" ] && echo 1 || echo 0 )"

rm -f "$EXPECT_SCRIPT"

echo "==> Installation phase complete"
echo "==> Booting installed system (no install media attached)"
echo "==> SSH should be available on localhost:${SSH_PORT}"

exec "${SCRIPT_DIR}/boot-qemu.sh" \
  --no-install-media \
  --name "$NAME" \
  --vm-dir "$VM_DIR" \
  --ram "$RAM_MB" \
  --cpus "$CPUS" \
  --boot-disk-size "$BOOT_DISK_SIZE" \
  --data-disk-count "$DATA_DISK_COUNT" \
  --data-disk-size "$DATA_DISK_SIZE" \
  --ssh-port "$SSH_PORT"
