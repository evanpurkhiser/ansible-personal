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

	echo home_assistant:
	echo '  hass_token:' \'"$(
		op item get 'mfv2dujsrfa4bl6hdexjwqwdoq' --field='Appdaemon Key'

	)"\'
	echo '  hacs_github_api_key:' \'"$(
		op item get 'mfv2dujsrfa4bl6hdexjwqwdoq' --field='HACS Github API Key'
	)"\'

	echo '  darksky_api_key:' \'"$(
		op item get 'skoxswyzgzh2dgwuc6d47lmnai' --field='API Key'
	)"\'

	echo '  apartment_bot_token:' \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --field='Apartment Bot Token'
	)"\'

	echo '  ecobee_api_key:' \'"$(
		op item get 'rr3xuvp23zanvbs4lqqadwt6yi' --field='API Key'
	)"\'

	echo "  google_assistant_service_account: |\n$(
		op document get 'xld4lu7ccfby7hjpo4efoulrru' | sed 's/\\n/\\\\n/g;s/^/    /'
	)"

	echo '  octoprint_api_key:' \'"$(
		op item get 'zwtxalkf65h2fa5inxwtv4h2tu' --field='HASS API Key'
	)"\'

	echo '  pge_password:' \'"$(
		op item get 'behtdcxervd35nul5222bcui3y' --field='password'
	)"\'

	# Cloudflare DNS credentials
	echo cloudflare:
	echo '  email:' \'"$(
		op item get 'z7qz2rxy6rb4xphfzmktsnauv4' --field='username'
	)"\'

	echo '  token:' \'"$(
		op item get 'z7qz2rxy6rb4xphfzmktsnauv4' --field='API Key'
	)"\'

	# Backup solution encryption and access token
	echo rclone:
	echo '  backup_key:' \'"$(
		op item get 'rzki4bpthbcx3dvunjvect545e' --field='password'
	)"\'

	echo '  backup_salt:' \'"$(
		op item get 'rzki4bpthbcx3dvunjvect545e' --field='salt'
	)"\'

	echo '  gdrive_token:' \'"$(
		# JSON format extration to avoid etra double quotes on the JSON string
		op item get 'rzki4bpthbcx3dvunjvect545e' --field='gdrive API Token' --format=json | jq -r .value
	)"\'

	# 2421 16th street Lutron
	echo lutron:
	echo "  caseta_crt: |\n$(
		op document get 'if7jhrbauracxa45xtlybscrja' | sed 's/^/    /'
	)"

	echo "  caseta_key: |\n$(
		op document get '5sxyarlqife5hfcmzn5zioit2e' | sed 's/^/    /'
	)"

	echo "  caseta_bridge_crt: |\n$(
		op document get 'mi47nw77vrbujg2bp5nnxztyuy' | sed 's/^/    /'
	)"

) >"$(dirname "$0")/vars/secrets.yml"
