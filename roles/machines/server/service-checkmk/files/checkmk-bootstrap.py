#!/usr/bin/env python3

import json
import os
import pathlib
import time
import urllib.error
import urllib.request


BASE_URL = "http://127.0.0.1:9009/monitoring/check_mk/api/v1"
AUTHORIZATION = f"Bearer cmkadmin {os.environ['CHECKMK_PASSWORD']}"
MARKER = pathlib.Path("/var/lib/checkmk/.server-bootstrapped")


def request(method, path, payload=None, headers=None, expected=(200,)):
    body = None if payload is None else json.dumps(payload).encode()
    request_headers = {
        "Accept": "application/json",
        "Authorization": AUTHORIZATION,
        **({} if headers is None else headers),
    }
    if body is not None:
        request_headers["Content-Type"] = "application/json"

    req = urllib.request.Request(
        BASE_URL + path,
        data=body,
        headers=request_headers,
        method=method,
    )
    try:
        response = urllib.request.urlopen(req, timeout=30)
    except urllib.error.HTTPError as error:
        if error.code in expected:
            return error

        detail = error.read().decode(errors="replace")
        raise RuntimeError(f"Checkmk API returned {error.code}: {detail}") from error

    if response.status not in expected:
        raise RuntimeError(f"Checkmk API returned {response.status}")

    return response


def wait_for_api():
    for _ in range(90):
        try:
            request("GET", "/version", expected=(200,))
            return
        except (OSError, RuntimeError):
            time.sleep(2)

    raise RuntimeError("Checkmk API did not become ready")


def ensure_host():
    response = request(
        "GET",
        "/objects/host_config/server",
        expected=(200, 404),
    )
    if response.status == 200:
        return

    request(
        "POST",
        "/domain-types/host_config/collections/all",
        payload={
            "host_name": "server",
            "folder": "/",
            "attributes": {"ipaddress": "10.88.0.1"},
        },
        expected=(200, 201),
    )


def discover_services():
    request(
        "POST",
        "/domain-types/service_discovery_run/actions/start/invoke",
        payload={"host_name": "server", "mode": "refresh"},
        expected=(200, 201, 204),
    )


def activate_changes():
    pending = request(
        "GET",
        "/domain-types/activation_run/collections/pending_changes",
    )
    if not json.load(pending).get("value"):
        return

    request(
        "POST",
        "/domain-types/activation_run/actions/activate-changes/invoke",
        payload={
            "redirect": False,
            "sites": ["monitoring"],
            "force_foreign_changes": False,
        },
        headers={"If-Match": pending.headers["ETag"]},
        expected=(200, 201, 204),
    )


wait_for_api()
ensure_host()
discover_services()
activate_changes()
MARKER.touch(mode=0o600)
