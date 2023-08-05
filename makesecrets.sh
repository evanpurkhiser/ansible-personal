#!/bin/sh

set -e

# All secrets for my personal machine configurations are stored in my personal
# 1password vault. This automatically extracts them.

# Ensure authentication
if ! op vault list >/dev/null; then
	echo "Signin to 1password using 'op signin'"
	exit 1
fi

# Access point credentials
(
	echo wifi_password: \'"$(
		op item get 'hnysllbhcfa4rmsmtko2x3naeq' --field='wireless network password'
	)"\'

	# Transmission RPC API HTTP password
	echo transmission_rpc_password: \'"$(
		op item get 'er47ejg7jjcgxh3ztyvzlsrlzy' --field='password'
	)"\'

	echo doppovich_bot_token: \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --field='Doppovich Bot Token'
	)"\'

	echo apartment_bot_token: \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --field='Apartment Bot Token'
	)"\'

	# Home assistant
	echo home_assistant:
	echo '  hass_token:' \'"$(
		op item get 'mfv2dujsrfa4bl6hdexjwqwdoq' --field='Appdaemon Key'

	)"\'

	echo '  hacs_github_api_key:' \'"$(
		op item get 'mfv2dujsrfa4bl6hdexjwqwdoq' --field='HACS Github API Key'
	)"\'

	echo "  google_assistant_service_account: |\n$(
		op document get 'mrlbmrn4ww6d6oneu26qtm467y' | sed 's/\\n/\\\\n/g;s/^/    /'
	)"

	echo '  pge_password:' \'"$(
		op item get 'behtdcxervd35nul5222bcui3y' --field='password'
	)"\'

	# Backup solution encryption and access token
	echo rclone:
	echo '  backup_key:' \'"$(
		op item get 'rzki4bpthbcx3dvunjvect545e' --field='password'
	)"\'

	echo '  backup_salt:' \'"$(
		op item get 'rzki4bpthbcx3dvunjvect545e' --field='salt'
	)"\'

	echo '  backup_backblaze_b2_account:' \'"$(
		op item get 'dgbdryr7swyphfakabjxljwwai' --field='rclone.keyId'
	)"\'

	echo '  backup_backblaze_b2_key:' \'"$(
		op item get 'dgbdryr7swyphfakabjxljwwai' --field='rclone.applicationKey'
	)"\'

) >"$(dirname "$0")/vars/secrets.yml"
