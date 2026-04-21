#!/usr/bin/env bash

set -euo pipefail

NAME="arch-server-lab-box"
VM_DIR="${HOME}/vms/${NAME}"
RAM_MB=4096
CPUS=4
SSH_FORWARD_PORT=2222
HEADLESS=0
UEFI=1
ENABLE_KVM=1

BASE_IMAGE_URL="https://fastly.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2"
BASE_IMAGE_SHA256_URL="https://fastly.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2.SHA256"

DATA_DISK_COUNT=5
DATA_DISK_SIZE="4T"
RESET_OVERLAY=0
COMPAT_NIC=0
SSH_VIA="lan"
PHASE="post-network"
INJECT_SSH_KEY_PATH=""
INJECT_SSH_USER="arch"
INJECT_SSH_PASSWORD="arch"
START_IN_TMUX=1
TMUX_SESSION=""

usage() {
  cat <<'EOF'
Boot a QEMU VM from the official Arch Linux arch-boxes basic image.

Usage:
  qemu/server/boot-qemu-archbox.sh [options]

Options:
  --name <name>             VM name (default: arch-server-lab-box)
  --vm-dir <path>           VM directory (default: ~/vms/<name>)
  --ram <mb>                Memory in MB (default: 4096)
  --cpus <count>            vCPU count (default: 4)
  --ssh-port <port>         Host port forwarded to guest:22 (default: 2222)
  --data-disk-count <n>     Number of extra SATA disks (default: 5)
  --data-disk-size <size>   Extra SATA disk size (default: 4T)
  --reset-overlay           Recreate overlay boot disk from base image
  --compat-nic              Use single compatibility NIC instead of server-shaped dual NIC
  --phase <bootstrap|post-network>
                            Network forwarding phase (default: post-network)
                            bootstrap:    LAN DHCP in 192.168.0.0/24, SSH -> 192.168.0.100
                            post-network: LAN static expectation 10.0.0.1, SSH -> 10.0.0.1
  --ssh-via <lan|wan>       Host SSH forwarding NIC in server-shaped mode (default: lan)
  --inject-ssh-key <path>   Inject public key after boot via password SSH
  --inject-ssh-user <user>  SSH user for key injection (default: arch)
  --inject-ssh-password <p> SSH password for key injection (default: arch)
  --no-tmux                 Run QEMU directly (default is tmux session)
  --tmux-session <name>     tmux session name (default: qemu-<vm-name>)
  --headless                Run without graphical display
  --no-kvm                  Disable KVM acceleration (useful in CI)
  --bios                    Use legacy BIOS firmware instead of UEFI
  -h, --help                Show this help

Notes:
  - Downloads Arch basic qcow2 image on first run.
  - Creates a writable overlay so the downloaded base image stays untouched.
  - Defaults to UEFI boot when OVMF firmware is available.
  - Arch basic image defaults: user 'arch', password 'arch', sshd enabled.
  - Default network shape uses two NICs with real-server MACs for lan0/wan0 rules.
  - Key injection waits for SSH, then appends key to ~/.ssh/authorized_keys.
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
    --ram)
      RAM_MB="$2"
      shift 2
      ;;
    --cpus)
      CPUS="$2"
      shift 2
      ;;
    --ssh-port)
      SSH_FORWARD_PORT="$2"
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
    --reset-overlay)
      RESET_OVERLAY=1
      shift
      ;;
    --compat-nic)
      COMPAT_NIC=1
      shift
      ;;
    --phase)
      PHASE="$2"
      shift 2
      ;;
    --ssh-via)
      SSH_VIA="$2"
      shift 2
      ;;
    --inject-ssh-key)
      INJECT_SSH_KEY_PATH="$2"
      shift 2
      ;;
    --inject-ssh-user)
      INJECT_SSH_USER="$2"
      shift 2
      ;;
    --inject-ssh-password)
      INJECT_SSH_PASSWORD="$2"
      shift 2
      ;;
    --no-tmux)
      START_IN_TMUX=0
      shift
      ;;
    --tmux-session)
      TMUX_SESSION="$2"
      shift 2
      ;;
    --headless)
      HEADLESS=1
      shift
      ;;
    --no-kvm)
      ENABLE_KVM=0
      shift
      ;;
    --bios)
      UEFI=0
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

require_cmd qemu-system-x86_64
require_cmd qemu-img
require_cmd curl
require_cmd sha256sum

if [ -n "$INJECT_SSH_KEY_PATH" ]; then
  require_cmd ssh
  require_cmd setsid
  if [ ! -f "$INJECT_SSH_KEY_PATH" ]; then
    echo "Public key file not found: $INJECT_SSH_KEY_PATH" >&2
    exit 1
  fi
fi

if [ "$START_IN_TMUX" -eq 1 ]; then
  require_cmd tmux
fi

IMAGE_DIR="${VM_DIR}/images"
DISK_DIR="${VM_DIR}/disks"
FIRMWARE_DIR="${VM_DIR}/firmware"
mkdir -p "$IMAGE_DIR" "$DISK_DIR"

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

BASE_IMAGE_PATH="${IMAGE_DIR}/Arch-Linux-x86_64-basic.qcow2"
BASE_IMAGE_SHA256_PATH="${IMAGE_DIR}/Arch-Linux-x86_64-basic.qcow2.SHA256"
OVERLAY_PATH="${DISK_DIR}/boot-overlay.qcow2"

if [ ! -f "$BASE_IMAGE_PATH" ]; then
  echo "Downloading arch-boxes base image..."
  curl -L --fail --output "$BASE_IMAGE_PATH" "$BASE_IMAGE_URL"
fi

echo "Downloading SHA256 checksum..."
curl -L --fail --output "$BASE_IMAGE_SHA256_PATH" "$BASE_IMAGE_SHA256_URL"

echo "Verifying base image checksum..."
(cd "$IMAGE_DIR" && sha256sum -c "$(basename "$BASE_IMAGE_SHA256_PATH")")

if [ "$RESET_OVERLAY" -eq 1 ] && [ -f "$OVERLAY_PATH" ]; then
  echo "Resetting overlay disk: $OVERLAY_PATH"
  rm -f "$OVERLAY_PATH"
fi

if [ ! -f "$OVERLAY_PATH" ]; then
  echo "Creating overlay disk: $OVERLAY_PATH"
  qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE_PATH" "$OVERLAY_PATH"
fi

QEMU_ARGS=(
  -name "$NAME"
  -machine q35
  -cpu host
  -smp "$CPUS"
  -m "$RAM_MB"
  -rtc base=utc
  -drive if=none,file="$OVERLAY_PATH",id=nvme0,format=qcow2
  -device nvme,drive=nvme0,serial=232880490001327413C4
  -device ich9-ahci,id=ahci
)

if [ "$ENABLE_KVM" -eq 1 ]; then
  QEMU_ARGS+=(
    -enable-kvm
  )
else
  QEMU_ARGS+=(
    -accel tcg,thread=multi
  )
fi

for i in $(seq 1 "$DATA_DISK_COUNT"); do
  DATA_DISK_PATH="${DISK_DIR}/data-sata${i}.qcow2"
  if [ ! -f "$DATA_DISK_PATH" ]; then
    echo "Creating data disk: $DATA_DISK_PATH ($DATA_DISK_SIZE)"
    qemu-img create -f qcow2 "$DATA_DISK_PATH" "$DATA_DISK_SIZE"
  fi
  QEMU_ARGS+=(
    -drive if=none,file="$DATA_DISK_PATH",id=sata${i},format=qcow2
    -device ide-hd,drive=sata${i},bus=ahci.$((i - 1)),serial=WDC-SATA-DISK-${i}
  )
done

if [ "$COMPAT_NIC" -eq 1 ]; then
  QEMU_ARGS+=(
    -netdev user,id=mgmt,hostfwd=tcp::${SSH_FORWARD_PORT}-:22
    -device virtio-net-pci,netdev=mgmt,mac=52:54:00:20:00:01
  )
else
  LAN_NET=""
  LAN_DHCPSTART=""
  SSH_TARGET=""

  if [ "$PHASE" = "bootstrap" ]; then
    LAN_NET="192.168.0.0/24"
    LAN_DHCPSTART="192.168.0.100"
    SSH_TARGET="192.168.0.100"
  elif [ "$PHASE" = "post-network" ]; then
    LAN_NET="10.0.0.0/24"
    LAN_DHCPSTART="10.0.0.15"
    SSH_TARGET="10.0.0.1"
  else
    echo "Invalid --phase value: $PHASE (expected bootstrap or post-network)" >&2
    exit 1
  fi

  if [ "$SSH_VIA" = "lan" ]; then
    QEMU_ARGS+=(
      -netdev user,id=lan,net=${LAN_NET},dhcpstart=${LAN_DHCPSTART},hostfwd=tcp::${SSH_FORWARD_PORT}-${SSH_TARGET}:22
      -device virtio-net-pci,netdev=lan,mac=d0:50:99:c2:9f:07
      -netdev user,id=wan
      -device virtio-net-pci,netdev=wan,mac=d0:50:99:c2:9f:08
    )
  elif [ "$SSH_VIA" = "wan" ]; then
    QEMU_ARGS+=(
      -netdev user,id=lan
      -device virtio-net-pci,netdev=lan,mac=d0:50:99:c2:9f:07
      -netdev user,id=wan,hostfwd=tcp::${SSH_FORWARD_PORT}-:22
      -device virtio-net-pci,netdev=wan,mac=d0:50:99:c2:9f:08
    )
  else
    echo "Invalid --ssh-via value: $SSH_VIA (expected lan or wan)" >&2
    exit 1
  fi
fi

QEMU_ARGS+=(
  -boot order=c,menu=on
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

echo "Starting VM '$NAME' from arch-boxes image"
echo "  VM dir:      $VM_DIR"
echo "  Boot overlay: $OVERLAY_PATH"
if [ "$UEFI" -eq 1 ]; then
  echo "  Firmware:    UEFI (OVMF)"
else
  echo "  Firmware:    BIOS"
fi
if [ "$ENABLE_KVM" -eq 1 ]; then
  echo "  Accel:       kvm"
else
  echo "  Accel:       tcg"
fi
echo "  SSH:         ssh arch@127.0.0.1 -p ${SSH_FORWARD_PORT}"
echo "  Credentials: arch / arch"
if [ "$COMPAT_NIC" -eq 1 ]; then
  echo "  NIC mode:    compatibility (single virtio-net)"
else
  echo "  NIC mode:    server-shape (dual virtio-net w/ real MACs, ssh via ${SSH_VIA})"
  echo "  Phase:       ${PHASE}"
fi

if [ -n "$INJECT_SSH_KEY_PATH" ]; then
  INJECT_LOG_PATH="/tmp/boot-qemu-archbox-keyinject-${NAME}.log"
  (
    ASKPASS_SCRIPT="$(mktemp)"
    KNOWN_HOSTS_PATH="$(mktemp)"
    trap 'rm -f "$ASKPASS_SCRIPT" "$KNOWN_HOSTS_PATH"' EXIT
    cat > "$ASKPASS_SCRIPT" <<'EOF'
#!/bin/sh
printf '%s\n' "$QEMU_INJECT_SSH_PASSWORD"
EOF
    chmod 700 "$ASKPASS_SCRIPT"

    ssh_ready=0
    for _ in $(seq 1 120); do
      if timeout 8 bash -lc "exec 3<>/dev/tcp/127.0.0.1/${SSH_FORWARD_PORT}; read -r -t 3 _ <&3" >/dev/null 2>&1; then
        ssh_ready=1
        break
      fi
      sleep 2
    done

    if [ "$ssh_ready" -ne 1 ]; then
      echo "SSH key injection skipped: port ${SSH_FORWARD_PORT} did not become ready" > "$INJECT_LOG_PATH"
      exit 0
    fi

    DISPLAY="${DISPLAY:-qemu-askpass}" SSH_ASKPASS="$ASKPASS_SCRIPT" SSH_ASKPASS_REQUIRE=force \
      QEMU_INJECT_SSH_PASSWORD="$INJECT_SSH_PASSWORD" \
      setsid -w ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile="$KNOWN_HOSTS_PATH" \
      -o ConnectTimeout=8 -p "$SSH_FORWARD_PORT" "${INJECT_SSH_USER}@127.0.0.1" \
      'mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys' \
      < "$INJECT_SSH_KEY_PATH" >"$INJECT_LOG_PATH" 2>&1 || true
  ) &
  disown >/dev/null 2>&1 || true
fi

if [ "$START_IN_TMUX" -eq 1 ]; then
  if [ -z "$TMUX_SESSION" ]; then
    TMUX_SESSION="qemu-${NAME}"
    TMUX_SESSION="${TMUX_SESSION//[^a-zA-Z0-9_-]/-}"
  fi

  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "tmux session '$TMUX_SESSION' already exists." >&2
    echo "Attach with: tmux attach -t $TMUX_SESSION" >&2
    exit 1
  fi

  QEMU_COMMAND="qemu-system-x86_64"
  for arg in "${QEMU_ARGS[@]}"; do
    QEMU_COMMAND+=" $(printf '%q' "$arg")"
  done

  tmux new-session -d -s "$TMUX_SESSION" "$QEMU_COMMAND"
  echo "Started tmux session: $TMUX_SESSION"
  echo "Attach with: tmux attach -t $TMUX_SESSION"
  exit 0
fi

exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
