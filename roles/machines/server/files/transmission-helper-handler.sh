#!/usr/bin/bash

set -euo pipefail

# Read the torrent hash from stdin
read -r torrent_hash

echo "Processing torrent hash: ${torrent_hash}"

/usr/bin/podman run --rm \
  --network=host \
  --uidmap 0:$(id -u evan):1 \
  --gidmap 0:$(id -g evan):1 \
  --uidmap 1:100000:65536 \
  --gidmap 1:100000:65536 \
  -v /mnt/documents/:/mnt/documents/ \
  -e TORRENT_HASH=${torrent_hash} \
  -e OPENAI_API_KEY=${OPENAI_API_KEY} \
  -e TELEGRAM_TOKEN=${TELEGRAM_TOKEN} \
  -e TELEGRAM_CHAT_ID="-722956237" \
  -e TRANSMISSION_BASE_URL="http://localhost:9091/" \
  -e MOVIES_DIR="/mnt/documents/multimedia/videos/movies" \
  -e TV_SERIES_DIR="/mnt/documents/multimedia/videos/series" \
  -e MOVE_COMPLETE_DIR="/mnt/documents/downloads/torrents-seeding/other" \
  -e SENTRY_DSN="https://254c85b83a782bab95ddca042bff1625@o126623.ingest.us.sentry.io/4509976585437184" \
  docker.io/evanpurkhiser/transmission-helper
