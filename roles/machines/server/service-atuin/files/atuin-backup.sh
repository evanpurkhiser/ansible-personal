#!/usr/bin/sh

set -e

# Dumps the atuin postgres database into the archived/ directory on the
# documents pool. zrepl snapshots and replicates this offsite, so we only need
# to keep a handful of recent dumps locally.

LOCATION="/mnt/documents/archived/atuin-backup"
FILE_NAME="atuin_$(date +'%Y-%m-%d_%H-%M').sql.gz"

podman exec -e PGPASSWORD=atuin atuin-postgres \
  pg_dump -U atuin -d atuin --clean --if-exists \
  | gzip >"${LOCATION}/${FILE_NAME}"

find "${LOCATION}" -name 'atuin_*.sql.gz' -mtime +7 -delete
