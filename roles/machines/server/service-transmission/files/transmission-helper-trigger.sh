#!/usr/bin/bash

set -euo pipefail

sock="/run/transmission-helper/helper.sock"
printf '%s\n' "$TR_TORRENT_HASH" | socat - UNIX-CONNECT:"$sock"
