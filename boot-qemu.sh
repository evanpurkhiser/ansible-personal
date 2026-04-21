#!/usr/bin/env bash

set -euo pipefail

NAME="arch-server-lab"
VM_DIR="${HOME}/vms/${NAME}"
RAM_MB=8192
CPUS=4
BOOT_DISK_SIZE="64G"
DATA_DISK_COUNT=5
DATA_DISK_SIZE="4T"
SSH_FORWARD_PORT=2222
HEADLESS=0
UEFI=1
ATTACH_INSTALL_MEDIA=1

ISO_URL="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
ISO_PATH=""

usage() {
  cat <<'EOF'
Boot a QEMU VM for Arch Linux installation.

Usage:
  ./boot-qemu.sh [options]

Options:
  --name <name>             VM name (default: arch-server-lab)
  --vm-dir <path>           VM directory (default: ~/vms/<name>)
  --iso-path <path>         Use an existing Arch ISO path
  --iso-url <url>           Override Arch ISO URL
  --ram <mb>                Memory in MB (default: 8192)
  --cpus <count>            vCPU count (default: 4)
  --boot-disk-size <size>   Boot disk size (default: 64G)
  --data-disk-count <n>     Number of data disks (default: 5)
  --data-disk-size <size>   Data disk size (default: 4T)
  --ssh-port <port>         Host port forwarded to guest:22 (default: 2222)
  --bios                    Use legacy BIOS firmware instead of UEFI
  --no-install-media        Do not attach Arch ISO (boot from disk)
  --headless                Run without graphical display
  -h, --help                Show this help

Notes:
  - Creates missing disks in <vm-dir>/disks.
  - Downloads Arch ISO into <vm-dir>/iso if missing.
  - Emulates two NICs (igb + e1000e) and five SATA data drives by default.
  - Defaults to UEFI boot when OVMF firmware is available.
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
    --name)
      NAME="$2"
      shift 2
      ;;
    --vm-dir)
      VM_DIR="$2"
      shift 2
      ;;
    --iso-path)
      ISO_PATH="$2"
      shift 2
      ;;
    --iso-url)
      ISO_URL="$2"
      shift 2
      ;;
    --ram)
      RAM_MB="$2"
      shift 2
      ;;
    --cpus)
      CPUS="$2"
      shift 2
      ;;
    --boot-disk-size)
      BOOT_DISK_SIZE="$2"
      shift 2
      ;;
    --data-disk-count)
      DATA_DISK_COUNT="$2"
      shift 2
      ;;
    --data-disk-size)
      DATA_DISK_SIZE="$2"
      shift 2
      ;;
    --ssh-port)
      SSH_FORWARD_PORT="$2"
      shift 2
      ;;
    --bios)
      UEFI=0
      shift
      ;;
    --no-install-media)
      ATTACH_INSTALL_MEDIA=0
      shift
      ;;
    --headless)
      HEADLESS=1
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

if [ -z "$ISO_PATH" ]; then
  ISO_PATH="${VM_DIR}/iso/archlinux-x86_64.iso"
fi

require_cmd qemu-system-x86_64
require_cmd qemu-img
require_cmd curl

DISK_DIR="${VM_DIR}/disks"
FIRMWARE_DIR="${VM_DIR}/firmware"
mkdir -p "$DISK_DIR" "$(dirname "$ISO_PATH")"

OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS_TEMPLATE="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
OVMF_VARS_LOCAL="${FIRMWARE_DIR}/OVMF_VARS.4m.fd"

if [ "$UEFI" -eq 1 ]; then
  if [ ! -f "$OVMF_CODE" ] || [ ! -f "$OVMF_VARS_TEMPLATE" ]; then
    echo "UEFI firmware not found. Install edk2-ovmf or use --bios." >&2
    exit 1
  fi
  mkdir -p "$FIRMWARE_DIR"
  if [ ! -f "$OVMF_VARS_LOCAL" ]; then
    cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS_LOCAL"
    chmod u+rw "$OVMF_VARS_LOCAL"
  fi
fi

BOOT_DISK_PATH="${DISK_DIR}/boot-nvme.qcow2"
if [ ! -f "$BOOT_DISK_PATH" ]; then
  echo "Creating boot disk: $BOOT_DISK_PATH ($BOOT_DISK_SIZE)"
  qemu-img create -f qcow2 "$BOOT_DISK_PATH" "$BOOT_DISK_SIZE"
fi

for i in $(seq 1 "$DATA_DISK_COUNT"); do
  DATA_DISK_PATH="${DISK_DIR}/data-sata${i}.qcow2"
  if [ ! -f "$DATA_DISK_PATH" ]; then
    echo "Creating data disk: $DATA_DISK_PATH ($DATA_DISK_SIZE)"
    qemu-img create -f qcow2 "$DATA_DISK_PATH" "$DATA_DISK_SIZE"
  fi
done

if [ "$ATTACH_INSTALL_MEDIA" -eq 1 ]; then
  if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading Arch ISO: $ISO_URL"
    curl -L --fail --output "$ISO_PATH" "$ISO_URL"
  fi
fi

declare -a QEMU_ARGS
QEMU_ARGS+=(
  -name "$NAME"
  -enable-kvm
  -cpu host
  -machine q35
  -smp "$CPUS"
  -m "$RAM_MB"
  -rtc base=utc
)

if [ "$UEFI" -eq 1 ]; then
  QEMU_ARGS+=(
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE"
    -drive if=pflash,format=raw,file="$OVMF_VARS_LOCAL"
  )
fi

if [ "$HEADLESS" -eq 1 ]; then
  QEMU_ARGS+=(
    -nographic
    -serial mon:stdio
  )
else
  QEMU_ARGS+=(
    -display gtk,gl=on
  )
fi

QEMU_ARGS+=(
  -drive if=none,file="$BOOT_DISK_PATH",id=nvme0,format=qcow2
  -device nvme,drive=nvme0,serial=232880490001327413C4
  -device ich9-ahci,id=ahci
)

for i in $(seq 1 "$DATA_DISK_COUNT"); do
  DATA_DISK_PATH="${DISK_DIR}/data-sata${i}.qcow2"
  QEMU_ARGS+=(
    -drive if=none,file="$DATA_DISK_PATH",id=sata${i},format=qcow2
    -device ide-hd,drive=sata${i},bus=ahci.$((i-1)),serial=WDC-SATA-DISK-${i}
  )
done

QEMU_ARGS+=(
  -netdev user,id=lan,hostfwd=tcp::${SSH_FORWARD_PORT}-:22
  -device igb,netdev=lan,mac=52:54:00:10:00:07
  -netdev user,id=wan
  -device e1000e,netdev=wan,mac=52:54:00:10:00:08
)

if [ "$ATTACH_INSTALL_MEDIA" -eq 1 ]; then
  QEMU_ARGS+=(
    -boot order=d,menu=on
    -cdrom "$ISO_PATH"
  )
else
  QEMU_ARGS+=(
    -boot order=c,menu=on
  )
fi

echo "Starting VM '$NAME'"
echo "  VM dir:      $VM_DIR"
if [ "$ATTACH_INSTALL_MEDIA" -eq 1 ]; then
  echo "  Arch ISO:    $ISO_PATH"
else
  echo "  Arch ISO:    (not attached)"
fi
if [ "$UEFI" -eq 1 ]; then
  echo "  Firmware:    UEFI (OVMF)"
else
  echo "  Firmware:    BIOS"
fi
echo "  SSH forward: localhost:${SSH_FORWARD_PORT} -> guest:22"

exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
