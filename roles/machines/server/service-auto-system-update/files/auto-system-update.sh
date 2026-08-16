#!/usr/bin/bash

set -euo pipefail

# Output to stderr so it bypasses sentry-cli and goes to systemd journal
exec 1>&2

state_dir=/home/evan/.local/state/system-updates
run_timestamp=$(date --utc +%Y-%m-%dT%H-%M-%SZ)
run_log="${state_dir}/runs/${run_timestamp}.log"

if update_output=$(sudo -u aur-builder yay -Syu --noconfirm 2>&1); then
	update_status=0
else
	update_status=$?
fi

{
	printf 'Command: yay -Syu --noconfirm\n'
	printf 'Invocation ID: %s\n' "${INVOCATION_ID:-unknown}"
	printf 'Exit status: %s\n\n' "${update_status}"
	printf '%s\n' "${update_output}"
} | sudo -H -u evan tee "${run_log}"

sudo -H -u evan ln -sfn "runs/${run_timestamp}.log" "${state_dir}/latest.log"

thread_name="System update $(date +%y.%m.%d)"
if codex_result=$(sudo -H -u evan env CODEX_HOME=/home/evan/.config/codex \
	/usr/local/bin/codex-oneshot \
	--working-dir "${state_dir}" \
	--thread-name "${thread_name}" \
	--prompt-file "${run_log}" \
	--developer-instructions-file /etc/auto-system-update.prompt \
	--sandbox read-only \
	--approval-policy never \
	--wait-for-reply \
	--timeout 600 \
	--json); then
	ai_summary=$(jq -r '.reply // empty' <<<"${codex_result}")
	thread_id=$(jq -r '.thread_id // empty' <<<"${codex_result}")
else
	ai_summary="The system update ran, but Codex could not summarize its output. Review the invocation log for details."
	thread_id=""
fi

if [[ -z "${ai_summary}" ]]; then
	ai_summary="The system update ran, but Codex returned an empty summary. Review the invocation log for details."
fi

if [[ -n "${thread_id}" ]]; then
	thread_status="Codex thread \`${thread_id}\`"
else
	thread_status="Codex thread unavailable"
fi

/usr/local/bin/purkhiser-bot.sh <<EOF
*🔄 System Update Report*

${ai_summary}

${thread_status}
Invocation \`${INVOCATION_ID:-unknown}\`
EOF
