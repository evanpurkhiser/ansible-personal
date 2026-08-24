#!/usr/bin/env bash

AGENT_AUTH_TAILSCALE_MACBOOK_PATTERN=${AGENT_AUTH_TAILSCALE_MACBOOK_PATTERN:-"macbook-.*"}
AGENT_AUTH_SSH_KEY=${AGENT_AUTH_SSH_KEY:-"/etc/ssh-agent-proxy-key"}
AGENT_AUTH_SSH_USER=${AGENT_AUTH_SSH_USER:-"evan"}
# The ssh-agent-proxy-serve forced command for this key recognizes this request
# as a readiness probe instead of forwarding it to the normal agent relay.
AGENT_AUTH_STATUS_REQUEST=$'AGENT-PROXY-STATUS/1\n'

AGENT_AUTH_SSH_OPTIONS=(
	-T
	-i "$AGENT_AUTH_SSH_KEY"
	-l "$AGENT_AUTH_SSH_USER"
	-o IdentitiesOnly=yes
	-o StrictHostKeyChecking=accept-new
	-o BatchMode=yes
)

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

agent_auth_macbook_is_ready() {
	local ip=$1
	local response

	response=$(
		printf '%s' "$AGENT_AUTH_STATUS_REQUEST" |
			timeout --foreground 2 ssh \
				"${AGENT_AUTH_SSH_OPTIONS[@]}" \
				-o ConnectTimeout=1 \
				-o ConnectionAttempts=1 \
				"$ip"
	) || return 1

	[[ "$response" == "ready" ]]
}

agent_auth_find_ready_macbook_route() {
	local name ip

	while IFS=$'\t' read -r name ip; do
		if ! agent_auth_macbook_is_ready "$ip"; then
			continue
		fi

		printf '%s\t%s\n' "$name" "$ip"
		return 0
	done < <(agent_auth_find_macbook_routes)

	return 1
}

agent_sudo_format_command() {
	printf 'sudo'

	local arg
	for arg in "$@"; do
		printf ' %q' "$arg"
	done
}
