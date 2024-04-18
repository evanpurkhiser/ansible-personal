#!/bin/sh

set -e

# All secrets for my personal machine configurations are stored in my personal
# 1password vault. This automatically extracts them.

# Ensure authentication
if ! op vault list >/dev/null; then
	echo "Signin to 1password using 'op signin'"
	exit 1
fi

(
	# Access point credentials
	echo wifi_password: \'"$(
		op item get 'hnysllbhcfa4rmsmtko2x3naeq' --field='wireless network password'
	)"\'

	# Public SSH Key
	echo public_ssh_key: \'"$(
		op item get 'szzjm25e6a4sgemptdt3qy5bvu' --field='public key'
	)"\'

	# Transmission RPC API HTTP password
	echo transmission_rpc_password: \'"$(
		op item get 'er47ejg7jjcgxh3ztyvzlsrlzy' --field='password'
	)"\'

	echo doppovich_bot_token: \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --field='Doppovich Bot Token'
	)"\'

	echo apartment_bot_token: \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --field='Purkhiser Bot'
	)"\'

	# Venmo auto cashout
	echo venmo_auto_cashout:

	echo '  venmo_token:' \'"$(
		op item get '3pab6f5j6zg5bpw762hq5swe4u' --field="API Token"
	)"\'
	echo '  lunchmoney_token:' \'"$(
		op item get 'iyur5zrspndy3j4uxifwa7mj4y' --field='Venmo Auto Cashout API Key'
	)"\'

	# Venmo Lunchmoney AI
	echo venmo_lunchmoney_ai:

	echo '  lunchmoney_token:' \'"$(
		op item get 'iyur5zrspndy3j4uxifwa7mj4y' --field='Venmo Lunchmoney AI API Key'
	)"\'
	echo '  openai_token:' \'"$(
		op item get 'fc4edctkopi57hlm476o6r46oq' --field='Venmo Lunchmoney AI API Key'
	)"\'
	echo '  telegram_token:' \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --field='Purkhiser Bot'
	)"\'

	# Home assistant
	echo home_assistant:

	echo '  hacs_github_api_key:' \'"$(
		op item get 'mfv2dujsrfa4bl6hdexjwqwdoq' --field='HACS Github API Key'
	)"\'
	echo '  virtual_doorman_token:' \'"$(
		op item get 'esnab34bolitnnm5o4jpjlckhy' --field="vdmauthtoken"
	)"\'

	# Backup solution encryption and access token
	echo rclone:
	echo '  backup_key:' \'"$(
		op item get 'rzki4bpthbcx3dvunjvect545e' --field='password'
	)"\'

	echo '  backup_salt:' \'"$(
		op item get 'rzki4bpthbcx3dvunjvect545e' --field='salt'
	)"\'

	echo "  gdrive_service_account: |\n$(
		op document get 'u4l25th5yzagzla7jntqvgqshi' | sed 's/\\n/\\\\n/g;s/^/    /'
	)"

) >"$(dirname "$0")/vars/secrets.yml"
