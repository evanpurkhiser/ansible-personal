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
		op read "op://Private/hnysllbhcfa4rmsmtko2x3naeq/wireless network password"
	)"\'

	# Public SSH Key
	echo public_ssh_key: \'"$(
		op read "op://Private/szzjm25e6a4sgemptdt3qy5bvu/public key"
	)"\'

	echo 'purkhiser_bot_token:' \'"$(
		op read "op://Private/wddknbssdbdpbilpy25olziegm/Purkhiser Bot"
	)"\'

	echo doppovich_bot_token: \'"$(
		op read "op://Private/wddknbssdbdpbilpy25olziegm/Doppovich Bot"
	)"\'

	echo apartment_bot_token: \'"$(
		op read "op://Private/wddknbssdbdpbilpy25olziegm/Purkhiser Bot"
	)"\'

	# nginx config
	echo nginx:

	echo "  cloudflare_cert: |\n$(
		op read "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Origin Certificate" | sed 's/\\n/\\\\n/g;s/^/    /'
	)"

	echo "  cloudflare_key: |\n$(
		op read "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Origin Private Key" | sed 's/\\n/\\\\n/g;s/^/    /'
	)"

	# Venmo auto cashout
	echo venmo_auto_cashout:

	echo '  venmo_token:' \'"$(
		op read "op://Private/3pab6f5j6zg5bpw762hq5swe4u/API Token"
	)"\'
	echo '  lunchmoney_token:' \'"$(
		op read "op://Private/iyur5zrspndy3j4uxifwa7mj4y/Venmo Auto Cashout API Key"
	)"\'

	# Venmo Lunchmoney AI
	echo venmo_lunchmoney_ai:

	echo '  lunchmoney_token:' \'"$(
		op read "op://Private/iyur5zrspndy3j4uxifwa7mj4y/Venmo Lunchmoney AI API Key"
	)"\'
	echo '  openai_token:' \'"$(
		op read "op://Private/fc4edctkopi57hlm476o6r46oq/Venmo Lunchmoney AI API Key"
	)"\'

	# Meal Log
	echo meal_log:

	echo '  record_token:' \'"$(
		op read "op://Private/l7fle3v7rksnryvm3i2cax4eqe/Record Token"
	)"\'
	echo '  openai_token:' \'"$(
		op read "op://Private/fc4edctkopi57hlm476o6r46oq/Meal Log API Key"
	)"\'
	echo '  r2_account_id:' \'"$(
		op read "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Account ID"
	)"\'
	echo '  r2_access_key_id:' \'"$(
		op read "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Access Key ID"
	)"\'
	echo '  r2_secret_access_key:' \'"$(
		op read "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Secret Access Key"
	)"\'

	# Instagram Saver
	echo instagram_saver:

	echo '  google_places_api_key:' \'"$(
		op read "op://Private/ss4qbfjbpbep7ph5prrdxxmena/Google Map Places API Key"
	)"\'
	echo '  openai_token:' \'"$(
		op read "op://Private/fc4edctkopi57hlm476o6r46oq/Instagram Saver API Key"
	)"\'

	# Bambu Lab P1S
	echo bambulab_printer:

	echo '  serial:' \'"$(
		op read "op://Private/rkrwve7w33m5x7xo7bhk3ppd4y/Printer Serial"
	)"\'
	echo '  access_code:' \'"$(
		op read "op://Private/rkrwve7w33m5x7xo7bhk3ppd4y/Printer Access Code"
	)"\'

	# opencode SSH agent proxy key
	echo "opencode_ssh_agent_proxy_key: |\n$(
		op read "op://Private/c2indiikwssnyfxsdsy7w6ac44/private key" | sed 's/\\n/\\\\n/g;s/^/    /'
	)"

	# Transmission Helper
	echo transmission_helper:

	echo '  openai_api_key:' \'"$(
		op read "op://Private/fc4edctkopi57hlm476o6r46oq/Transmission Helper API Key"
	)"\'
	echo '  telegram_token:' \'"$(
		op read "op://Private/wddknbssdbdpbilpy25olziegm/Purkhiser Bot"
	)"\'

	# Auto System Update
	echo auto_system_update:

	echo '  openai_api_key:' \'"$(
		op read "op://Private/fc4edctkopi57hlm476o6r46oq/Auto System Update API Key"
	)"\'

	# Home assistant
	echo home_assistant:

	echo '  hacs_github_api_key:' \'"$(
		op read "op://Private/mfv2dujsrfa4bl6hdexjwqwdoq/HACS Github API Key"
	)"\'
	echo '  virtual_doorman_token:' \'"$(
		op read "op://Private/esnab34bolitnnm5o4jpjlckhy/vdmauthtoken"
	)"\'
	echo '  youtube_data_api_key:' \'"$(
		op read "op://Private/ss4qbfjbpbep7ph5prrdxxmena/YouTube Data API Key"
	)"\'
	echo '  lunchmoney_token:' \'"$(
		op read "op://Private/iyur5zrspndy3j4uxifwa7mj4y/Home Assistant API Key"
	)"\'

	# Things3
	echo things3:
	echo '  email:' \'"$(
		op read "op://Private/lwymezf6azedfiebtvb2qv2ahi/username"
	)"\'
	echo '  password:' \'"$(
		op read "op://Private/lwymezf6azedfiebtvb2qv2ahi/password"
	)"\'

	# Offsite WiFi networks
	# PSK values are wpa_passphrase pre-computed hashes stored in 1password
	echo offsite_wifi_networks:
	echo "  - ssid: \"Purkhiser\""
	echo "    psk: $(op read "op://Private/hnysllbhcfa4rmsmtko2x3naeq/psk")"
	echo "  - ssid: \"PurkhiserWifi\""
	echo "    psk: $(op read "op://Private/2t6zlp23zfvgrw642wdblecemy/psk")"

) >"$(dirname "$0")/vars/secrets.yml"
