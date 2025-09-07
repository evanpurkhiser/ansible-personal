#!/bin/bash

set -euo pipefail

source /etc/transmission-helper.conf

if [ -z "${TR_TORRENT_HASH:-}" ]; then
  echo "Error: TR_TORRENT_HASH environment variable is not set"
  exit 1
fi

podman run -d \
  --network=host \
  -v /mnt/documents/:/mnt/documents/ \
  -e TORRENT_HASH="$TR_TORRENT_HASH" \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e TELEGRAM_TOKEN="$TELEGRAM_TOKEN" \
  -e TELEGRAM_CHAT_ID="-722956237" \
  -e TRANSMISSION_BASE_URL="http://localhost:9091/" \
  -e MOVIES_DIR="/mnt/documents/multimedia/videos/movies" \
  -e TV_SERIES_DIR="/mnt/documents/multimedia/videos/series" \
  -e MOVE_COMPLETE_DIR="/mnt/documents/downloads/torrents-seeding/other" \
  -e SENTRY_DSN="https://254c85b83a782bab95ddca042bff1625@o126623.ingest.us.sentry.io/4509976585437184" \
  docker.io/evanpurkhiser/transmission-helper:latest
