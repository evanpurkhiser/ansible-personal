#!/bin/sh
# Build the Alpine LBU overlay (apkovl) for the offsite server.
#
# Spins up an Alpine container, applies the offsite Ansible playbook inside it,
# runs `lbu package` to produce the overlay tarball, then copies it out.
#
# Usage:
#   ./build-offsite-lbu.sh [output-dir]
#
# Output:
#   <output-dir>/offsite.apkovl.tar.gz  (default: ./dist)

set -e

CONTAINER_NAME="ansible-offsite-build"
ALPINE_IMAGE="docker.io/library/alpine:3.23"
OUTPUT_DIR="${1:-$(dirname "$0")/dist}"
OUTPUT_FILE="$OUTPUT_DIR/offsite.apkovl.tar.gz"
SSH_PORT=2222
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_KEY="/tmp/build-ssh-key"

cleanup() {
	echo "==> Stopping build container..."
	podman rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"

# Ensure secrets are available
if [ ! -f "$SCRIPT_DIR/vars/secrets.yml" ]; then
	echo "==> Generating secrets from 1password..."
	sh "$SCRIPT_DIR/makesecrets.sh"
fi

# Generate a throwaway SSH key for connecting to the build container.
# This avoids any empty-password workarounds and keeps sshd_config stock.
# TODO(container-workaround): key only needed for the build container.
if [ ! -f "$BUILD_KEY" ]; then
	ssh-keygen -t ed25519 -N "" -f "$BUILD_KEY" -C "ansible-offsite-build" >/dev/null
fi
BUILD_PUBKEY="$(cat "${BUILD_KEY}.pub")"

# Pull image if needed
echo "==> Pulling Alpine $ALPINE_IMAGE..."
podman pull "$ALPINE_IMAGE"

# Start a privileged container with SSH port forwarded.
# Inject the build public key into root's authorized_keys so Ansible can connect.
# TODO(container-workaround): privileged + key injection only needed for build.
# Ensure /var/log/apk.log exists and is writable for apk logging.
echo "==> Starting build container..."
podman run -d \
	--name "$CONTAINER_NAME" \
	--privileged \
	--no-hosts \
	-p "127.0.0.1:${SSH_PORT}:22" \
	-v "${BUILD_KEY}.pub:/tmp/build.pub:ro" \
	"$ALPINE_IMAGE" \
	sh -c "mkdir -p /var/log && touch /var/log/apk.log && chmod 644 /var/log/apk.log && \
            apk add --no-cache openssh python3 alpine-conf && \
            ssh-keygen -A && \
            mkdir -p /root/.ssh && \
           cat /tmp/build.pub > /root/.ssh/authorized_keys && \
           chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
           echo offsite > /etc/hostname && \
           mkdir -p /run/openrc && echo sysinit > /run/openrc/softlevel && \
           ip link set lo up && \
           mkdir -p /run/openrc/started && ln -sf /etc/init.d/networking /run/openrc/started/networking && \
           rc-service sshd start && \
           tail -f /dev/null"

# Wait for SSH to be ready
echo "==> Waiting for SSH..."
ssh-keygen -R "[127.0.0.1]:${SSH_PORT}" 2>/dev/null || true
for i in $(seq 1 120); do
	if ssh -o StrictHostKeyChecking=no \
		-o ConnectTimeout=2 \
		-i "$BUILD_KEY" \
		-p "$SSH_PORT" root@127.0.0.1 true 2>/dev/null; then
		echo "==> SSH ready after ${i}s"
		break
	fi
	if [ "$i" -eq 120 ]; then
		echo "ERROR: SSH never became ready" >&2
		exit 1
	fi
	sleep 1
done

echo "==> Running Ansible playbook..."
ANSIBLE_HOST_KEY_CHECKING=False \
	ansible-playbook "$SCRIPT_DIR/play-offsite.yml" \
	-i "offsite," \
	-e "ansible_host=127.0.0.1" \
	-e "ansible_port=$SSH_PORT" \
	-e "ansible_user=root" \
	-e "ansible_ssh_private_key_file=$BUILD_KEY" \
	-e "ansible_python_interpreter=/usr/bin/python3"

echo "==> Removing build SSH key from authorized_keys..."
podman exec "$CONTAINER_NAME" sh -c "grep -v 'ansible-offsite-build' /root/.ssh/authorized_keys > /tmp/ak && mv /tmp/ak /root/.ssh/authorized_keys"

echo "==> Running lbu package inside container..."
podman exec "$CONTAINER_NAME" sh -c "mkdir -p /tmp/lbu-out && lbu package /tmp/lbu-out/offsite.apkovl.tar.gz"

echo "==> Copying apkovl out of container..."
podman cp "$CONTAINER_NAME:/tmp/lbu-out/offsite.apkovl.tar.gz" "$OUTPUT_FILE"

echo ""
echo "==> Built: $OUTPUT_FILE"
echo "    $(du -h "$OUTPUT_FILE" | cut -f1)  $(tar -tzf "$OUTPUT_FILE" | wc -l) files"
