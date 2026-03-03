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
	echo "    MIIDEzCCAfugAwIBAgIUDUUWUe3hJogOtXl7w38RK3NGpjQwDQYJKoZIhvcNAQEL"
	echo "    BQAwGTEXMBUGA1UEAwwOZmFrZS10ZXN0LWNlcnQwHhcNMjYwMzAzMjM0MTM5WhcN"
	echo "    MjcwMzAzMjM0MTM5WjAZMRcwFQYDVQQDDA5mYWtlLXRlc3QtY2VydDCCASIwDQYJ"
	echo "    KoZIhvcNAQEBBQADggEPADCCAQoCggEBAJp0e/lC9G2JrrmX3xXZ+ypEYQKuRq90"
	echo "    XgulUH0UfpHcsHpVqvlFS85tgRQARojnDz5rYbAhRVcmaseLHgT2c03VVIjUI3N/"
	echo "    EKrr5RT3GgUCCJNLSbN+kgAqxXN9TAMtfTShLPu2iUCFgcCyVhPYkHomdVQb2gUR"
	echo "    WVjCo/ccAdGmP357+QtfnZYv8tLU2+ncmR3zGpLpM/ATnECv6poetlkt0RuijqXk"
	echo "    sDq/bFqX1gtjGtuZ9scDV51bhc2SsPSepDYfb7w6U8A15pIyYd0rjVyNw1Uy/Gi+"
	echo "    LLlSMWPJz46qTiKZ9WYMrKPk3mrL3hL987zt80YtuF+HaPrXkL0lBi0CAwEAAaNT"
	echo "    MFEwHQYDVR0OBBYEFLug+C/WF9Yy1dQY+aQF/49qLDXNMB8GA1UdIwQYMBaAFLug"
	echo "    +C/WF9Yy1dQY+aQF/49qLDXNMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQEL"
	echo "    BQADggEBAHRmGuLsu3ZG+xb3te2qG4Qb//pPgTS53ojMZFmeYkdbT48xVbFXTrQA"
	echo "    UCCcuutel5eDQab5c78yU8MuDaz0pqijE8faLfIXetzRz5zLbXpMTLxnGFAwSO/s"
	echo "    UrgPygiwedL5APxNh/S/ZWHoWJY/jFU6jqYHL1NlMniw+A9fmzFDNBei7UCM9BEI"
	echo "    ppWo+gwUJxpT+Jq2ZVCt80SCMOQlgFCPCqpvem6skBVdl1a/pCGL2cEDZ75ey7dc"
	echo "    aH0OuIu/tuXH1aS4ehfgDGVY6z48c/IMSDLUHyh7mcuxFO9cjFCnIXm8d2x4OOrv"
	echo "    d5fY3fiTT4c6UK4zdOhya5+pjR8Hpxw="
	echo "    -----END CERTIFICATE-----"
	echo "  cloudflare_key: |"
	echo "    -----BEGIN PRIVATE KEY-----"
	echo "    MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCadHv5QvRtia65"
	echo "    l98V2fsqRGECrkavdF4LpVB9FH6R3LB6Var5RUvObYEUAEaI5w8+a2GwIUVXJmrH"
	echo "    ix4E9nNN1VSI1CNzfxCq6+UU9xoFAgiTS0mzfpIAKsVzfUwDLX00oSz7tolAhYHA"
	echo "    slYT2JB6JnVUG9oFEVlYwqP3HAHRpj9+e/kLX52WL/LS1Nvp3Jkd8xqS6TPwE5xA"
	echo "    r+qaHrZZLdEboo6l5LA6v2xal9YLYxrbmfbHA1edW4XNkrD0nqQ2H2+8OlPANeaS"
	echo "    MmHdK41cjcNVMvxoviy5UjFjyc+Oqk4imfVmDKyj5N5qy94S/fO87fNGLbhfh2j6"
	echo "    15C9JQYtAgMBAAECggEADdCfwBlJhJH9OKjJXDUoPne+7Omf9T86zt7aoVLCdBMh"
	echo "    uSd4HfNL8ar2Ec8T1ViZZ/NchE+i2fCGj3zgKAB6gA/gj5vYjz2NGkSe3lkFu5nw"
	echo "    IMCUrIMvKuhTIIkopzDGk1Jb6X3CWVeNAKp9gX6W2Z4eqMcUS+y+fu5rPQXaccvB"
	echo "    vnBUaaQtfXLtA4DwdkKCdDZ0oODmyXkGqDeCqRC4eahjoqxh/X5fpD1XEuuHGGsY"
	echo "    19YNNEgH1TzM9MjtD1rKBPdRhWyKEu7hD4CMu8m2DJrvuOzvizqgCHe/NoyjAWuI"
	echo "    /gxeJwOdk2jHQMfaPF9QVvj8mw6zNmVsCVjYVQuenwKBgQDWWI1L7HZSwdYSpvyt"
	echo "    MOF+x71ZFKYavV7/QgxDdz71qelxHpji2eq1ptougecCyHiESHGOglRJJmkD5dHy"
	echo "    b9C9JCXmdyJJ3xMO8jQ/L/rSsBdh4YimE6uWhtxcD2RGyYNdM1y+JHcc1l2H92FN"
	echo "    G6FOfxjxKZmUzaXHnmZEYZsclwKBgQC4eG72hUo1xh4Y3kqtp6MM0zRFSCEBQ4rG"
	echo "    2e7AuZPzRRGzxWX+mt2X2ffy4tU0IQaG7bH5MeqR0506jjU5oibES77r0+oUsIYH"
	echo "    nIuJRRtlJGMmiV0W59VamiXl0ytf9o7tx3lqq8TkLxs4P7Qf1JxxBqjd3JXYTbtp"
	echo "    pTD5w24X2wKBgE4YeXK+NuY0JZEqMknP03jjwYNhWJvJf4E1SU6Tdeb//0Ptx/pv"
	echo "    N2rz3e6v+cEz1WUtF+K6bYcxbXW0GGhigQVI1F5B7cZIdqMtcAfNrW9yJTLOf4Ez"
	echo "    DYOMo2EPYpO//BLLEfFdS+C/4dgWM+dqN71n5WiIpaJnww0WE2C6x08FAoGAH8aX"
	echo "    Dp3tJ5Al9RCtenZK7tWexmRjUw1oZVJ6/vW4l4oJP5c8N3xDuXmRbWRHZ4Bc2Hcv"
	echo "    VgaUKmRyS/jdED1vQhbuHz9UrhWuMLd1jcK6slRvQ98biuuKY93zs0AJ07Dr8+eN"
	echo "    caN++fNnU+wdQfJktE96XSU3JphVNSCAbDWOzEsCgYAHHPFLISM0E8FGSkrUefdm"
	echo "    69kZq5/x/aWQdNp5eLatJPEm98rwVz3EJOX+LRQ3dTzPNj0Xh91Alk63tjXI+hS/"
	echo "    LBQFf5Q38antd8lrOJWDtObPeLga3E3saZg4CSeZaKujxU2w+buL6g+KrmXbB3Nd"
	echo "    WLhruduNMJit8As2cdEC0w=="
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
