#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# dependencies = ["pyyaml"]
# ///
#
# All secrets for my personal machine configurations are stored in my personal
# 1password vault. This script extracts them via `op read` (parallelized) and
# writes vars/secrets.yml.

import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import yaml

type Secrets = str | dict[str, "Secrets"] | list["Secrets"]

SECRETS: Secrets = {
    # Access point credentials
    "wifi_password": "op://Private/hnysllbhcfa4rmsmtko2x3naeq/wireless network password",

    # Public SSH Key
    "public_ssh_key": "op://Private/szzjm25e6a4sgemptdt3qy5bvu/public key",

    # Telegram bots
    "purkhiser_bot_token": "op://Private/wddknbssdbdpbilpy25olziegm/Purkhiser Bot",
    "doppovich_bot_token": "op://Private/wddknbssdbdpbilpy25olziegm/Doppovich Bot",
    "apartment_bot_token": "op://Private/wddknbssdbdpbilpy25olziegm/Purkhiser Bot",

    # nginx config
    "nginx": {
        "cloudflare_cert": "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Origin Certificate",
        "cloudflare_key": "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Origin Private Key",
    },

    # Venmo auto cashout
    "venmo_auto_cashout": {
        "venmo_token": "op://Private/3pab6f5j6zg5bpw762hq5swe4u/API Token",
        "lunchmoney_token": "op://Private/iyur5zrspndy3j4uxifwa7mj4y/Venmo Auto Cashout API Key",
    },

    # Venmo Lunchmoney AI
    "venmo_lunchmoney_ai": {
        "lunchmoney_token": "op://Private/iyur5zrspndy3j4uxifwa7mj4y/Venmo Lunchmoney AI API Key",
        "openai_token": "op://Private/fc4edctkopi57hlm476o6r46oq/Venmo Lunchmoney AI API Key",
    },

    # Meal Log
    "meal_log": {
        "record_token": "op://Private/l7fle3v7rksnryvm3i2cax4eqe/Record Token",
        "openai_token": "op://Private/fc4edctkopi57hlm476o6r46oq/Meal Log API Key",
        "r2_account_id": "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Account ID",
        "r2_access_key_id": "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Access Key ID",
        "r2_secret_access_key": "op://Private/z7qz2rxy6rb4xphfzmktsnauv4/Secret Access Key",
    },

    # Instagram Saver
    "instagram_saver": {
        "google_places_api_key": "op://Private/ss4qbfjbpbep7ph5prrdxxmena/Google Map Places API Key",
        "openai_token": "op://Private/fc4edctkopi57hlm476o6r46oq/Instagram Saver API Key",
    },

    # Bambu Lab P1S
    "bambulab_printer": {
        "serial": "op://Private/rkrwve7w33m5x7xo7bhk3ppd4y/Printer Serial",
        "access_code": "op://Private/rkrwve7w33m5x7xo7bhk3ppd4y/Printer Access Code",
    },

    # opencode SSH agent proxy key
    "opencode_ssh_agent_proxy_key": "op://Private/c2indiikwssnyfxsdsy7w6ac44/private key",

    # Transmission Helper
    "transmission_helper": {
        "openai_api_key": "op://Private/fc4edctkopi57hlm476o6r46oq/Transmission Helper API Key",
        "telegram_token": "op://Private/wddknbssdbdpbilpy25olziegm/Purkhiser Bot",
    },

    # Auto System Update
    "auto_system_update": {
        "openai_api_key": "op://Private/fc4edctkopi57hlm476o6r46oq/Auto System Update API Key",
    },

    # Home assistant
    "home_assistant": {
        "hacs_github_api_key": "op://Private/mfv2dujsrfa4bl6hdexjwqwdoq/HACS Github API Key",
        "virtual_doorman_token": "op://Private/esnab34bolitnnm5o4jpjlckhy/vdmauthtoken",
        "youtube_data_api_key": "op://Private/ss4qbfjbpbep7ph5prrdxxmena/YouTube Data API Key",
        "lunchmoney_token": "op://Private/iyur5zrspndy3j4uxifwa7mj4y/Home Assistant API Key",
    },

    # Things3
    "things3": {
        "email": "op://Private/lwymezf6azedfiebtvb2qv2ahi/username",
        "password": "op://Private/lwymezf6azedfiebtvb2qv2ahi/password",
    },

    # Offsite WiFi networks
    # PSK values are wpa_passphrase pre-computed hashes stored in 1password
    "offsite_wifi_networks": [
        {"ssid": "Purkhiser", "psk": "op://Private/hnysllbhcfa4rmsmtko2x3naeq/psk"},
        {"ssid": "PurkhiserWifi", "psk": "op://Private/2t6zlp23zfvgrw642wdblecemy/psk"},
    ],
}


def ensure_authenticated() -> None:
    result = subprocess.run(["op", "vault", "list"], capture_output=True)
    if result.returncode != 0:
        sys.exit("Sign in to 1password using 'op signin'")


def collect_refs(data: Secrets) -> set[str]:
    if isinstance(data, dict):
        return {ref for v in data.values() for ref in collect_refs(v)}
    if isinstance(data, list):
        return {ref for v in data for ref in collect_refs(v)}
    if data.startswith("op://"):
        return {data}
    return set()


def resolve_ref(ref: str) -> str:
    result = subprocess.run(["op", "read", ref], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"failed to resolve {ref!r}: {result.stderr.strip()}")
    value = result.stdout.removesuffix("\n")
    # Multi-line values (certs, keys) conventionally end with a newline, and
    # keeping one makes PyYAML emit `|` instead of `|-`.
    if "\n" in value:
        value += "\n"
    return value


def substitute(data: Secrets, resolved: dict[str, str]) -> Secrets:
    if isinstance(data, dict):
        return {k: substitute(v, resolved) for k, v in data.items()}
    if isinstance(data, list):
        return [substitute(v, resolved) for v in data]
    if data.startswith("op://"):
        return resolved[data]
    return data


def inject_secrets(data: Secrets, max_workers: int = 16) -> Secrets:
    refs = sorted(collect_refs(data))
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        values = list(pool.map(resolve_ref, refs))
    return substitute(data, dict(zip(refs, values)))


def _str_representer(dumper: yaml.Dumper, data: str) -> yaml.ScalarNode:
    style = "|" if "\n" in data else None
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style=style)


yaml.add_representer(str, _str_representer)


def main() -> None:
    ensure_authenticated()
    resolved = inject_secrets(SECRETS)
    output = yaml.dump(resolved, sort_keys=False, allow_unicode=True, width=10**9)
    (Path(__file__).parent / "vars" / "secrets.yml").write_text(output)


if __name__ == "__main__":
    main()
