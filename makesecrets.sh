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
        op get item 'hnysllbhcfa4rmsmtko2x3naeq' |
            jq -r '.details.sections[].fields[]? | select(.n == "wireless_password").v'
    )"\'

    # Transmission RPC API HTTP password
    echo transmission_rpc_password: \'"$(
        op get item 'er47ejg7jjcgxh3ztyvzlsrlzy' |
            jq -r '.details.fields[] | select(.name == "password").value'
    )"\'

    echo home_assistant:
    echo '  hacs_github_api_key:' \'"$(
        op get item 'mfv2dujsrfa4bl6hdexjwqwdoq' |
            jq -r '.details.sections[].fields[]? | select(.n == "3E7D5DBE346F4EED8B1F69B2DA1F32A1").v'
    )"\'

    echo '  spotify_api_key:' \'"$(
        op get item 'y4pxpl6oezgavidgfzvcb2nome' |
            jq -r '.details.sections[].fields[]? | select(.n == "0959D6B98BE74F40BF981214E1D1A491").v'
    )"\'

    echo '  spotify_username:' \'"$(
        op get item 'y4pxpl6oezgavidgfzvcb2nome' |
            jq -r '.details.fields[] | select(.name == "username").value'
    )"\'

    echo '  spotify_password:' \'"$(
        op get item 'y4pxpl6oezgavidgfzvcb2nome' |
            jq -r '.details.fields[] | select(.name == "password").value'
    )"\'

    echo '  darksky_api_key:' \'"$(
        op get item 'skoxswyzgzh2dgwuc6d47lmnai' |
            jq -r '.details.sections[].fields[]? | select(.n == "CFB4195D54E34F0FAB8F25968FE7958A").v'
    )"\'

    echo '  telegram_bot_token:' \'"$(
        op get item 'wddknbssdbdpbilpy25olziegm' |
            jq -r '.details.sections[].fields[]? | select(.n == "58F0E29A9DFC4A6691E9A913A627A9E5").v'
    )"\'

    echo '  ecobee_api_key:' \'"$(
        op get item 'rr3xuvp23zanvbs4lqqadwt6yi' |
            jq -r '.details.sections[].fields[]? | select(.n == "0F81E181656B412FBBD687137544BA1F").v'
    )"\'

    echo "  google_assistant_service_account: |\n$(
        op get document 'xld4lu7ccfby7hjpo4efoulrru' | sed 's/\\n/\\\\n/g;s/^/    /'
    )"

    # Cloudflare DNS credentials
    echo cloudflare:
    echo '  email:' \'"$(
        op get item 'z7qz2rxy6rb4xphfzmktsnauv4' |
            jq -r '.details.fields[] | select(.name == "username").value'
    )"\'

    echo '  token:' \'"$(
        op get item 'z7qz2rxy6rb4xphfzmktsnauv4' |
            jq -r '.details.sections[].fields[]? | select(.n == "B12E0ECF27AC4357B784CCF59A455C49").v'
    )"\'

    # Backup solution encryption and access token
    echo rclone:
    echo '  backup_key:' \'"$(
        op get item 'rzki4bpthbcx3dvunjvect545e' | jq -r '.details.password'
    )"\'

    echo '  backup_salt:' \'"$(
        op get item 'rzki4bpthbcx3dvunjvect545e' |
            jq -r '.details.sections[].fields[]? | select(.n == "C1C73CD15D304C168BA41338A0792881").v'
    )"\'

    echo '  gdrive_token:' \'"$(
        op get item 'rzki4bpthbcx3dvunjvect545e' |
            jq -r '.details.sections[].fields[]? | select(.n == "A36E5CA6867D4AE385AAC496F302535B").v'
    )"\'

    # 2421 16th street Lutron
    echo lutron:
    echo "  caseta_crt: |\n$(
        op get document 'if7jhrbauracxa45xtlybscrja' | sed 's/^/    /'
    )"

    echo "  caseta_key: |\n$(
        op get document '5sxyarlqife5hfcmzn5zioit2e' | sed 's/^/    /'
    )"

    echo "  caseta_bridge_crt: |\n$(
        op get document 'mi47nw77vrbujg2bp5nnxztyuy' | sed 's/^/    /'
    )"

) >"$(dirname "$0")/vars/secrets.yml"
