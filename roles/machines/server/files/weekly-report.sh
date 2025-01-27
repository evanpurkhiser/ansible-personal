#!/usr/bin/bash

set -e

echo "*Weekly server.home.evanpurkhiser.com report*"
echo ""

# Uptime
echo "⏳ $(uptime -p)"

# IP Address
addr_v4="$(ip -4 addr show wan0 | grep -oP '(?<=inet\s)[\d.]+')"
addr_v6="$(ip -6 addr show wan0 | grep -oP '(?<=inet6\s)(?!fe80)[\da-f:]+')"
echo "🌐 "'`'"${addr_v4}"'`'" / "'`'"${addr_v6}"'`'

# Load average
load_avg="$(cat /proc/loadavg | awk '{ print $1, $2, $3 }')"
echo '⚡ *load average*: `'"$load_avg"'` (1m, 5m, 15m)'

# memory usage
memory="$(free -h --si | awk '/^Mem:/ {print "*used*: " $3 " / *free*: " $4 " (" $2 ")"}')"
echo "🧠 $memory"

# Temperatures
temp_cpu="$(sensors coretemp-isa-0000 -j | jq '."coretemp-isa-0000"."Package id 0".temp1_input | (. * 10 | round / 10)')"
temp_mem="$(sensors jc42-i2c-1-1a -j | jq '."jc42-i2c-1-1a".temp1.temp1_input | (. * 10 | round / 10)')"
temp_ssd="$(sensors nvme-pci-0500 -j | jq '."nvme-pci-0500".Composite.temp1_input | (. * 10 | round / 10)')"
echo "❄️ *cpu:* ${temp_cpu}° / *mem:* ${temp_mem}° / *ssd:* ${temp_ssd}"

# Outdated packages
echo "📦 *$(pacman -Qu | wc -l)* outdated packages"

# Disk usages
function usage() {
  df $1 -h --output=used,avail,pcent | tail -n +2 | awk '{printf "*used;* %s / *avail:* %s (%s)", $1,$2,$3}'
}
echo "💾 $(usage /dev/nvme0n1p2)"
echo "🗂️ $(usage /mnt/documents)"

# zpool status
zpool_status="$(zpool status -x)"
if [[ "$zpool_status" != "all pools are healthy" ]]; then
  echo "🌊 \[zpool] *${zpool_status}* ‼️"
else
  echo "🌊 \[zpool] ${zpool_status}"
fi
echo ""

# Systemd service status
services="$(systemctl list-units --type=service --output=json |
  jq '{
    active: ([.[] | select(.active == "active")] | length),
    failed: ([.[] | select(.active == "failed")] | length), 
    inactive: ([.[] | select(.active == "inactive")] | length)
  }' |
  jq -r '"\(if .failed > 0 then "‼️ " else "" end)*active:* \(.active) / *failed:* \(.failed) / *inactive:* \(.inactive)"')"
echo "🛠️ \[systemd] ${services}"

# Torrents
torrents_downloading="$(transmission-remote -l | grep 'Downloading' | wc -l)"
torrents_seeding="$(transmission-remote -l | grep 'Seeding' | wc -l)"
torrents_idle="$(transmission-remote -l | grep 'Idle' | wc -l)"
echo "📡 \[transmission] *down:* ${torrents_downloading} / *seeding:* ${torrents_seeding} / *idle:* ${torrents_idle}"
echo ""

echo "🐳 *Podman containers*"
podman_ps="$(podman ps --format=json | jq -r '.[] | "\(.Names[0])\t\(.Status)"' | column -s$'\t' -t)"
echo -ne '```contaienrs\n'"${podman_ps}" '```\n'
echo ""

# rclone sync last run
rclone_last_invocation="$(journalctl -u rclone-sync --output=json -r -n 1 | jq -r .INVOCATION_ID)"
rclone_last_ts="$(
  journalctl INVOCATION_ID=$rclone_last_invocation --output=json -n 1 |
    jq -r .__REALTIME_TIMESTAMP |
    while read ts; do date -d "@$((ts / 1000000))" +"%Y-%m-%d %H:%M:%S"; done
)"
rclone_last_run="$(journalctl INVOCATION_ID=$rclone_last_invocation --output=json | jq -r .MESSAGE)"
echo "🔄 *rclone last run* ($rclone_last_ts)"
echo -ne '```journalctl\n'"${rclone_last_run}" '```\n'
