#!/usr/bin/bash
set -euo pipefail
umask 077

# Completed dumps are snapshotted and replicated offsite by zrepl.
location=/mnt/documents/backups/places
file="$location/places_$(date +'%Y-%m-%d_%H-%M-%S').dump"
temporary=$(mktemp "$location/.places.XXXXXX")
trap 'rm -f "$temporary"' EXIT
podman exec places-postgres pg_dump -U places -d places --format=custom >"$temporary"
mv "$temporary" "$file"
find "$location" -name 'places_*.dump' -mtime +7 -delete
