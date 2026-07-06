#!/usr/bin/env bash

AGENT_AUTH_TAILSCALE_MACBOOK_PATTERN=${AGENT_AUTH_TAILSCALE_MACBOOK_PATTERN:-"macbook-.*"}

agent_auth_find_macbook_route() {
	tailscale status --json 2>/dev/null | jq -r --arg pattern "$AGENT_AUTH_TAILSCALE_MACBOOK_PATTERN" '
    [
      .Peer[]?
      | select(.DNSName | test($pattern))
      | select(.Online == true)
    ]
    | sort_by([
        (if .Active then 1 else 0 end),
        (if .LastHandshake == "0001-01-01T00:00:00Z" then "" else .LastHandshake end)
    ])
    | last
    | if . == null then empty else [(.DNSName | sub("\\.$"; "")), .TailscaleIPs[0]] | @tsv end
  '
}

agent_auth_find_macbook() {
	local name ip
	IFS=$'\t' read -r name ip < <(agent_auth_find_macbook_route)

	if [[ -z "${ip:-}" ]]; then
		return 1
	fi

	printf '%s\n' "$ip"
}

agent_sudo_format_command() {
	printf 'sudo'

	local arg
	for arg in "$@"; do
		printf ' %q' "$arg"
	done
}
