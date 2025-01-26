#/usr/bin/sh

set -e

# Records all files in /mnt/documents into the file-history archive. This is
# useful in the scenario where I have a catastophic data loss and I would like
# to know what files I had that were NOT being backed up (such as large media)

LOCATION="/mnt/documents/archived/file-history"
FILE_NAME="$(date +'%Y-%m-%d_%H-%M').txt"

mkdir -p "${LOCATION}"

fd . /mnt/documents | sort | gzip >"${LOCATION}/${FILE_NAME}"
gzip "${LOCATION}/${FILE_NAME}"
