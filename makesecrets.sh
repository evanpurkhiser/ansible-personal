#!/bin/sh

set -e

# All secrets for my personal machine configurations are stored in my personal
# 1password vault. This automatically extracts them.

# Ensure authentication
if ! op list vaults >/dev/null; then
    echo "Signin to 1password using 'op signin'"
    exit 1
fi

# Access point credentials
(
    echo wifi_password: \'"$(
        op get item 'pscarwpmj5bqpf57rqv4gfrsjq' | \
            jq -r '.details.sections[].fields[]? | select(.n == "wireless_password").v'
    )"\'

    # Transmission RPC API HTTP password
    echo transmission_rpc_password: \'"$(
        op get item 'er47ejg7jjcgxh3ztyvzlsrlzy' | \
            jq -r '.details.fields[] | select(.name == "password").value'
    )"\'

    # Home Assistant API key
    echo home_assistant:
    echo '  api_key:' \'"$(
        op get item 'mfv2dujsrfa4bl6hdexjwqwdoq' | \
            jq -r '.details.sections[].fields[]? | select(.n == "DF8748D4968D48A7BA2D7B9CC8D45989").v'
    )"\'

    echo '  google_assistant_api_key:' \'"$(
        op get item 'mfv2dujsrfa4bl6hdexjwqwdoq' | \
            jq -r '.details.sections[].fields[]? | select(.n == "DB83962019C2412B9E89D97529A352DD").v'
    )"\'

    echo '  spotify_api_key:' \'"$(
        op get item 'y4pxpl6oezgavidgfzvcb2nome' | \
            jq -r '.details.sections[].fields[]? | select(.n == "0959D6B98BE74F40BF981214E1D1A491").v'
    )"\'

    echo '  darksky_api_key:' \'"$(
        op get item 'skoxswyzgzh2dgwuc6d47lmnai' | \
            jq -r '.details.sections[].fields[]? | select(.n == "CFB4195D54E34F0FAB8F25968FE7958A").v'
    )"\'

    # Cloudflare DNS credentials
    echo cloudflare:
    echo '  email:' \'"$(
        op get item 'z7qz2rxy6rb4xphfzmktsnauv4' | \
            jq -r '.details.fields[] | select(.name == "username").value'
    )"\'

    echo '  token:' \'"$(
        op get item 'z7qz2rxy6rb4xphfzmktsnauv4' | \
            jq -r '.details.sections[].fields[]? | select(.n == "B12E0ECF27AC4357B784CCF59A455C49").v'
    )"\'

    # Backup solution encryption and access token
    echo rclone:
    echo '  backup_key:' \'"$(
        op get item 'rzki4bpthbcx3dvunjvect545e' | jq -r '.details.password'
    )"\'

    echo '  backup_salt:' \'"$(
        op get item 'rzki4bpthbcx3dvunjvect545e'| \
            jq -r '.details.sections[].fields[]? | select(.n == "C1C73CD15D304C168BA41338A0792881").v'
    )"\'

    echo '  gdrive_token:' \'"$(
        op get item 'rzki4bpthbcx3dvunjvect545e'| \
            jq -r '.details.sections[].fields[]? | select(.n == "A36E5CA6867D4AE385AAC496F302535B").v'
    )"\'
) > "$(dirname "$0")/vars/secrets.yml"
