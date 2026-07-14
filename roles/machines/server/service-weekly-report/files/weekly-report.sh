#!/usr/bin/bash

set -e

echo "*Weekly server.home.evanpurkhiser.com report*"
echo ""

# Uptime
echo "⏳ $(uptime -p)"

# Load average
load_avg="$(cat /proc/loadavg | awk '{ print $1, $2, $3 }')"
echo '📊 *load average*: `'"$load_avg"'` (1m, 5m, 15m)'

# memory usage
memory="$(free -h --si | awk '/^Mem:/ {print "*used*: " $3 " / *free*: " $4 " (" $2 ")"}')"
echo "🧠 $memory"

# Temperatures
temp_cpu="$(sensors coretemp-isa-0000 -j | jq '."coretemp-isa-0000"."Package id 0".temp1_input | (. * 10 | round / 10)')"
temp_mem="$(sensors -j | jq 'first(to_entries[] | select(.key | startswith("jc42-")) | .value.temp1.temp1_input) | (. * 10 | round / 10)')"
temp_ssd="$(sensors nvme-pci-0500 -j | jq '."nvme-pci-0500".Composite.temp1_input | (. * 10 | round / 10)')"
echo "❄️ *cpu:* ${temp_cpu}° / *mem:* ${temp_mem}° / *ssd:* ${temp_ssd}"

# Disk usages
function usage() {
	df $1 -h --output=used,avail,pcent | tail -n +2 | awk '{printf "*used:* %s / *avail:* %s (%s)", $1,$2,$3}'
}
echo "💾 $(usage /dev/nvme0n1p2)"
echo "🗂️ $(usage /mnt/documents)"

# IP Address
addr_v4="$(ip -4 addr show wan0 | grep -oP '(?<=inet\s)[\d.]+')"
addr_v6="$(ip -6 addr show wan0 | grep -oP '(?<=inet6\s)(?!fe80)[\da-f:]+')"
echo "🌐 "'`'"${addr_v4}"'`'" / "'`'"${addr_v6}"'`'

# Speed test
# speedtest-monitor runs twice daily, so take the last 14 runs for the past weeks average
speed_down="$(tail -14 /var/local/speedtest-monitor.json | jq .download | awk '{sum+=$1/1048576; count++} END {printf "%.2f Mbps\n", sum/count}')"
speed_up="$(tail -14 /var/local/speedtest-monitor.json | jq .upload | awk '{sum+=$1/1048576; count++} END {printf "%.2f Mbps\n", sum/count}')"

echo "⚡ ${speed_down} down / ${speed_up} up"
echo ""

# zpool status
zpool_status="$(zpool status -x)"
if [[ "$zpool_status" != "all pools are healthy" ]]; then
	echo "🌊 \[zpool] *${zpool_status}* ‼️"
else
	echo "🌊 \[zpool] ${zpool_status}"
fi

# ZFS snapshots
latest_snapshot_ts=$(zfs list -t snapshot -r documents -o creation -H -p -s creation | tail -1)
age_hours=$((($(date +%s) - latest_snapshot_ts) / 3600))
if [ $age_hours -lt 24 ]; then
	snapshot_age="${age_hours} hours ago"
else
	age_days=$((age_hours / 24))
	snapshot_age="${age_days} days ago"
fi

# Get the size difference between last two snapshots
snapshot_sizes=$(zfs list -t snapshot -r documents -o used -H -p -s creation | tail -2)
if [ $(echo "$snapshot_sizes" | wc -l) -eq 2 ]; then
	prev_size=$(echo "$snapshot_sizes" | head -1)
	curr_size=$(echo "$snapshot_sizes" | tail -1)
	size_diff=$((curr_size - prev_size))

	# Convert to human readable
	if [ $size_diff -lt 0 ]; then
		abs_diff=$((-size_diff))
		sign="-"
	else
		abs_diff=$size_diff
		sign="+"
	fi

	if [ $abs_diff -ge 1099511627776 ]; then
		size_human=$(awk "BEGIN {printf \"%.1f TB\", $abs_diff/1099511627776}")
	elif [ $abs_diff -ge 1073741824 ]; then
		size_human=$(awk "BEGIN {printf \"%.1f GB\", $abs_diff/1073741824}")
	elif [ $abs_diff -ge 1048576 ]; then
		size_human=$(awk "BEGIN {printf \"%.1f MB\", $abs_diff/1048576}")
	else
		size_human=$(awk "BEGIN {printf \"%.1f KB\", $abs_diff/1024}")
	fi

	echo "📸 \[zrepl] Last snapshot ${snapshot_age} (${sign}${size_human})"
else
	echo "📸 \[zrepl] Last snapshot ${snapshot_age}"
fi

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
echo -ne '```containers\n'"${podman_ps}" '```\n'
echo ""
