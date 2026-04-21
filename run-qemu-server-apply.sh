#!/usr/bin/env bash

set -euo pipefail

NAME="archbox-server-lab"
VM_DIR="/tmp/${NAME}"
SSH_PORT="2254"
SSH_HOST="127.0.0.1"
SSH_USER="arch"
SSH_KEY="/tmp/ansible-qemu"
SECRETS_FILE="vars/secrets.fake.yml"
DATA_DISK_SIZE="20G"
PREPARE_FAKE_DEVICES=1

BOOTSTRAP_SESSION=""
POST_SESSION=""

APPLY_EXTRA_ARGS=()

usage() {
  cat <<'EOF'
Run the full two-phase server apply against a QEMU arch-box VM.

Usage:
  ./run-qemu-server-apply.sh [options] [-- <extra ansible-playbook args>]

Options:
  --name <name>             VM name (default: archbox-server-lab)
  --vm-dir <path>           VM dir (default: /tmp/<name>)
  --ssh-host <host>         VM host/IP (default: 127.0.0.1)
  --ssh-port <port>         Forwarded SSH port (default: 2254)
  --ssh-user <user>         SSH user (default: arch)
  --ssh-key <path>          SSH private key path (default: /tmp/ansible-qemu)
  --secrets-file <path>     Secrets source file (default: vars/secrets.fake.yml)
  --data-disk-size <size>   QEMU data disk size (default: 20G)
  --no-fake-devices         Skip creating /dev/zigbee and /dev/zwave symlinks
  --bootstrap-session <n>   tmux session for phase 1
  --post-session <n>        tmux session for phase 2
  -h, --help                Show help

Flow:
  1) Boot phase=bootstrap
  2) Ensure SSH key access
  3) Run first full apply (expected to stop at intervention)
  4) Graceful poweroff
  5) Boot phase=post-network
  6) Run second full apply
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --name)
      NAME="$2"
      shift 2
      ;;
    --vm-dir)
      VM_DIR="$2"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT="$2"
      shift 2
      ;;
    --ssh-host)
      SSH_HOST="$2"
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
    --secrets-file)
      SECRETS_FILE="$2"
      shift 2
      ;;
    --data-disk-size)
      DATA_DISK_SIZE="$2"
      shift 2
      ;;
    --no-fake-devices)
      PREPARE_FAKE_DEVICES=0
      shift
      ;;
    --bootstrap-session)
      BOOTSTRAP_SESSION="$2"
      shift 2
      ;;
    --post-session)
      POST_SESSION="$2"
      shift 2
      ;;
    --)
      shift
      APPLY_EXTRA_ARGS=("$@")
      break
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

if [[ -z "$BOOTSTRAP_SESSION" ]]; then
  BOOTSTRAP_SESSION="qemu-${NAME}-bootstrap"
fi
if [[ -z "$POST_SESSION" ]]; then
  POST_SESSION="qemu-${NAME}-post"
fi

require_cmd tmux
require_cmd ssh
require_cmd ssh-keygen

if [[ ! -x "./boot-qemu-archbox.sh" ]]; then
  echo "Missing executable script: ./boot-qemu-archbox.sh" >&2
  exit 1
fi

if [[ ! -x "./apply-server-qemu.sh" ]]; then
  echo "Missing executable script: ./apply-server-qemu.sh" >&2
  exit 1
fi

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Secrets file not found: $SECRETS_FILE" >&2
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  mkdir -p "$(dirname "$SSH_KEY")"
  ssh-keygen -t ed25519 -N "" -f "$SSH_KEY" -C "ansible-qemu" >/dev/null
fi

SSH_PUB_KEY="${SSH_KEY}.pub"
if [[ ! -f "$SSH_PUB_KEY" ]]; then
  echo "Missing SSH public key: $SSH_PUB_KEY" >&2
  exit 1
fi

KNOWN_HOSTS_FILE="$(mktemp)"

SSH_COMMON=(
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile="$KNOWN_HOSTS_FILE"
  -o ConnectTimeout=3
  -p "$SSH_PORT"
)

cleanup() {
  rm -f "$KNOWN_HOSTS_FILE"
}
trap cleanup EXIT

wait_for_key_ssh() {
  local attempts="$1"
  for _ in $(seq 1 "$attempts"); do
    if timeout 5 ssh "${SSH_COMMON[@]}" "${SSH_USER}@${SSH_HOST}" "true" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

apply_once() {
  local args=(
    "--ssh-host" "$SSH_HOST"
    "--ssh-user" "$SSH_USER"
    "--ssh-port" "$SSH_PORT"
    "--ssh-key" "$SSH_KEY"
    "--secrets-file" "$SECRETS_FILE"
  )

  if [[ "${#APPLY_EXTRA_ARGS[@]}" -gt 0 ]]; then
    args+=(-- "${APPLY_EXTRA_ARGS[@]}")
  fi

  ./apply-server-qemu.sh "${args[@]}"
}

prepare_fake_devices() {
  if [[ "$PREPARE_FAKE_DEVICES" -ne 1 ]]; then
    return 0
  fi

  timeout 5 ssh "${SSH_COMMON[@]}" "${SSH_USER}@${SSH_HOST}" \
    "sudo ln -sf /dev/null /dev/zwave && sudo ln -sf /dev/null /dev/zigbee" >/dev/null
}

echo "==> Starting bootstrap phase VM"
tmux kill-session -t "$BOOTSTRAP_SESSION" 2>/dev/null || true
./boot-qemu-archbox.sh \
  --headless \
  --name "$NAME" \
  --vm-dir "$VM_DIR" \
  --reset-overlay \
  --phase bootstrap \
  --ssh-port "$SSH_PORT" \
  --data-disk-size "$DATA_DISK_SIZE" \
  --inject-ssh-key "$SSH_PUB_KEY" \
  --tmux-session "$BOOTSTRAP_SESSION"

if ! wait_for_key_ssh 30; then
  echo "SSH key auth not ready after bootstrap wait." >&2
  echo "Attach serial with: tmux attach -t $BOOTSTRAP_SESSION" >&2
  exit 1
fi

echo "==> Phase 1 apply"
apply_once

echo "==> Prepare fake zigbee/zwave devices"
prepare_fake_devices

echo "==> Graceful poweroff after phase 1"
timeout 5 ssh "${SSH_COMMON[@]}" "${SSH_USER}@${SSH_HOST}" "sudo poweroff" >/dev/null || true

for _ in $(seq 1 60); do
  if tmux has-session -t "$BOOTSTRAP_SESSION" 2>/dev/null; then
    sleep 2
  else
    break
  fi
done
tmux kill-session -t "$BOOTSTRAP_SESSION" 2>/dev/null || true

echo "==> Starting post-network phase VM"
tmux kill-session -t "$POST_SESSION" 2>/dev/null || true
./boot-qemu-archbox.sh \
  --headless \
  --name "$NAME" \
  --vm-dir "$VM_DIR" \
  --phase post-network \
  --ssh-port "$SSH_PORT" \
  --data-disk-size "$DATA_DISK_SIZE" \
  --tmux-session "$POST_SESSION"

wait_for_key_ssh 90 || {
  echo "Post-network SSH did not become ready." >&2
  echo "Attach serial with: tmux attach -t $POST_SESSION" >&2
  exit 1
}

echo "==> Prepare fake zigbee/zwave devices (post-network)"
prepare_fake_devices

echo "==> Phase 2 apply"
apply_once

echo "==> Full two-phase run complete"
echo "Serial session still available at: tmux attach -t $POST_SESSION"
