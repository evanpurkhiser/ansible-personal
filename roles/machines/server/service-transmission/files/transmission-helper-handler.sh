#!/usr/bin/bash

set -euo pipefail

# Read the torrent hash from stdin
read -r torrent_hash

echo "Processing torrent hash: ${torrent_hash}"

exec /usr/bin/podman run --rm \
	--network=host \
	--uidmap "0:$(id -u evan):1" \
	--gidmap "0:$(id -g evan):1" \
	--uidmap 1:100000:65536 \
	--gidmap 1:100000:65536 \
	-v /mnt/documents/:/mnt/documents/ \
	-v /etc/transmission-helper.yaml:/config/transmission-helper.yaml:ro \
	-e TORRENT_HASH="${torrent_hash}" \
	-e TRANSMISSION_HELPER_CONFIG=/config/transmission-helper.yaml \
	-e OPENAI_API_KEY="${OPENAI_API_KEY}" \
	-e TELEGRAM_TOKEN="${TELEGRAM_TOKEN}" \
	ghcr.io/evanpurkhiser/transmission-helper
