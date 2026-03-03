#!/bin/sh

set -e

# Generate fake secrets for testing the ansible playbook
# This mimics the structure of makesecrets.sh but with dummy values

echo "Generating fake secrets for testing..."

(
	# Access point credentials
	echo "wifi_password: 'fake-wifi-password'"

	# Public SSH Key (use the one generated in CI, or a dummy one)
	echo "public_ssh_key: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC fake-key-for-testing'"

	# Telegram bots
	echo "purkhiser_bot_token: 'fake-telegram-bot-token-purkhiser'"
	echo "doppovich_bot_token: 'fake-telegram-bot-token-doppovich'"
	echo "apartment_bot_token: 'fake-telegram-bot-token-apartment'"

	# nginx config (self-signed cert for testing)
	echo "nginx:"
	echo "  cloudflare_cert: |"
	echo "    -----BEGIN CERTIFICATE-----"
	echo "    MIICljCCAX4CCQCKz8Vz1fF5+TANBgkqhkiG9w0BAQsFADANMQswCQYDVQQGEwJV"
	echo "    UzAeFw0yNDAzMDMwMDAwMDBaFw0yNTAzMDMwMDAwMDBaMA0xCzAJBgNVBAYTAlVT"
	echo "    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAfake"
	echo "    -----END CERTIFICATE-----"
	echo "  cloudflare_key: |"
	echo "    -----BEGIN PRIVATE KEY-----"
	echo "    MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQB8fake"
	echo "    -----END PRIVATE KEY-----"

	# Venmo auto cashout
	echo "venmo_auto_cashout:"
	echo "  venmo_token: 'fake-venmo-token'"
	echo "  lunchmoney_token: 'fake-lunchmoney-token-cashout'"

	# Venmo Lunchmoney AI
	echo "venmo_lunchmoney_ai:"
	echo "  lunchmoney_token: 'fake-lunchmoney-token-ai'"
	echo "  openai_token: 'fake-openai-token-venmo'"

	# Meal Log
	echo "meal_log:"
	echo "  record_token: 'fake-meal-log-record-token'"
	echo "  openai_token: 'fake-openai-token-meal-log'"
	echo "  r2_account_id: 'fake-r2-account-id'"
	echo "  r2_access_key_id: 'fake-r2-access-key'"
	echo "  r2_secret_access_key: 'fake-r2-secret-key'"

	# Instagram Saver
	echo "instagram_saver:"
	echo "  google_places_api_key: 'fake-google-places-api-key'"
	echo "  openai_token: 'fake-openai-token-instagram'"

	# Bambu Lab P1S
	echo "bambulab_printer:"
	echo "  serial: '00P00A3B1234567'"
	echo "  access_code: '12345678'"

	# Transmission Helper
	echo "transmission_helper:"
	echo "  openai_api_key: 'fake-openai-token-transmission'"
	echo "  telegram_token: 'fake-telegram-bot-token-transmission'"

	# Auto System Update
	echo "auto_system_update:"
	echo "  openai_api_key: 'fake-openai-token-system-update'"

	# Home assistant
	echo "home_assistant:"
	echo "  hacs_github_api_key: 'ghp_fakegithubtoken1234567890'"
	echo "  virtual_doorman_token: 'fake-virtual-doorman-token'"
	echo "  youtube_data_api_key: 'fake-youtube-api-key'"
	echo "  lunchmoney_token: 'fake-lunchmoney-token-hass'"

) >"$(dirname "$0")/vars/secrets.yml"

echo "Fake secrets generated at vars/secrets.yml"
