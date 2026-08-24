#!/usr/bin/env bash

AGENT_AUTH_TAILSCALE_MACBOOK_PATTERN=${AGENT_AUTH_TAILSCALE_MACBOOK_PATTERN:-"macbook-.*"}

agent_auth_find_macbook_routes() {
	tailscale status --json 2>/dev/null | jq -r --arg pattern "$AGENT_AUTH_TAILSCALE_MACBOOK_PATTERN" '
    [
      .Peer[]?
      | select(.DNSName | test($pattern))
      | select(.Online == true)
    ]
    | sort_by(
        if .LastHandshake == "0001-01-01T00:00:00Z"
        then ""
        else .LastHandshake
        end
      )
    | reverse
    | .[]
    | [(.DNSName | sub("\\.$"; "")), .TailscaleIPs[0]]
    | @tsv
  '
}

agent_auth_find_macbook_route() {
	agent_auth_find_macbook_routes | head -n 1
}

agent_sudo_format_command() {
	printf 'sudo'

	local arg
	for arg in "$@"; do
		printf ' %q' "$arg"
	done
}
