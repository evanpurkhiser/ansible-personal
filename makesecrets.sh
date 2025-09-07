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
		op item get 'hnysllbhcfa4rmsmtko2x3naeq' --reveal --field='wireless network password'
	)"\'

	# Public SSH Key
	echo public_ssh_key: \'"$(
		op item get 'szzjm25e6a4sgemptdt3qy5bvu' --reveal --field='public key'
	)"\'

	echo 'purkhiser_bot_token:' \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --reveal --field='Purkhiser Bot'
	)"\'

	echo doppovich_bot_token: \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --reveal --field='Doppovich Bot'
	)"\'

	echo apartment_bot_token: \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --reveal --field='Purkhiser Bot'
	)"\'

	# nginx config
	echo nginx:

	# Transmission RPC API HTTP password
	echo '  transmission_rpc_password:' \'"$(
		op item get 'er47ejg7jjcgxh3ztyvzlsrlzy' --reveal --field='password'
	)"\'

	echo "  cloudflare_cert: |\n$(
		op item get 'z7qz2rxy6rb4xphfzmktsnauv4' --field='Origin Certificate' | tr -d '"' | sed 's/\\n/\\\\n/g;s/^/    /'
	)"

	echo "  cloudflare_key: |\n$(
		op item get 'z7qz2rxy6rb4xphfzmktsnauv4' --field='Origin Private Key' | tr -d '"' | sed 's/\\n/\\\\n/g;s/^/    /'
	)"

	# Venmo auto cashout
	echo venmo_auto_cashout:

	echo '  venmo_token:' \'"$(
		op item get '3pab6f5j6zg5bpw762hq5swe4u' --reveal --field="API Token"
	)"\'
	echo '  lunchmoney_token:' \'"$(
		op item get 'iyur5zrspndy3j4uxifwa7mj4y' --reveal --field='Venmo Auto Cashout API Key'
	)"\'

	# Venmo Lunchmoney AI
	echo venmo_lunchmoney_ai:

	echo '  lunchmoney_token:' \'"$(
		op item get 'iyur5zrspndy3j4uxifwa7mj4y' --reveal --field='Venmo Lunchmoney AI API Key'
	)"\'
	echo '  openai_token:' \'"$(
		op item get 'fc4edctkopi57hlm476o6r46oq' --reveal --field='Venmo Lunchmoney AI API Key'
	)"\'

	# Meal Log
	echo meal_log:

	echo '  record_token:' \'"$(
		op item get 'l7fle3v7rksnryvm3i2cax4eqe' --reveal --field 'Record Token'
	)"\'
	echo '  openai_token:' \'"$(
		op item get 'fc4edctkopi57hlm476o6r46oq' --reveal --field='Meal Log API Key'
	)"\'
	echo '  r2_account_id:' \'"$(
		op item get 'z7qz2rxy6rb4xphfzmktsnauv4' --reveal --field='Account ID'
	)"\'
	echo '  r2_access_key_id:' \'"$(
		op item get 'z7qz2rxy6rb4xphfzmktsnauv4' --reveal --field='Access Key ID'
	)"\'
	echo '  r2_secret_access_key:' \'"$(
		op item get 'z7qz2rxy6rb4xphfzmktsnauv4' --reveal --field='Secret Access Key'
	)"\'

	# Instagram Saver
	echo instagram_saver:

	echo '  google_places_api_key:' \'"$(
		op item get 'ss4qbfjbpbep7ph5prrdxxmena' --reveal --field='Google Map Places API Key'
	)"\'
	echo '  openai_token:' \'"$(
		op item get 'fc4edctkopi57hlm476o6r46oq' --reveal --field='Instagram Saver API Key'
	)"\'

	# Bambu Lab P1S
	echo bambulab_printer:

	echo '  serial:' \'"$(
		op item get 'rkrwve7w33m5x7xo7bhk3ppd4y' --reveal --field='Printer Serial'
	)"\'
	echo '  access_code:' \'"$(
		op item get 'rkrwve7w33m5x7xo7bhk3ppd4y' --reveal --field='Printer Access Code'
	)"\'

	# Transmission Helper
	echo transmission_helper:

	echo '  openai_api_key:' \'"$(
		op item get 'fc4edctkopi57hlm476o6r46oq' --reveal --field='Transmission Helper API Key'
	)"\'
	echo '  telegram_token:' \'"$(
		op item get 'wddknbssdbdpbilpy25olziegm' --reveal --field='Purkhiser Bot'
	)"\'

	# Home assistant
	echo home_assistant:

	echo '  hacs_github_api_key:' \'"$(
		op item get 'mfv2dujsrfa4bl6hdexjwqwdoq' --reveal --field='HACS Github API Key'
	)"\'
	echo '  virtual_doorman_token:' \'"$(
		op item get 'esnab34bolitnnm5o4jpjlckhy' --reveal --field="vdmauthtoken"
	)"\'

	# Backup solution encryption and access token
	echo rclone:

	echo '  backup_key:' \'"$(
		op item get 'rzki4bpthbcx3dvunjvect545e' --reveal --field='password'
	)"\'

	echo '  backup_salt:' \'"$(
		op item get 'rzki4bpthbcx3dvunjvect545e' --reveal --field='salt'
	)"\'

	echo "  gdrive_service_account: |\n$(
		op document get 'u4l25th5yzagzla7jntqvgqshi' | sed 's/\\n/\\\\n/g;s/^/    /'
	)"

) >"$(dirname "$0")/vars/secrets.yml"
