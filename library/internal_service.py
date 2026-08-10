#!/usr/bin/python

from __future__ import absolute_import, division, print_function

__metaclass__ = type

DOCUMENTATION = r"""
---
module: internal_service
short_description: Expose a local HTTP service through Tailscale and nginx
description:
  - Idempotently registers a local HTTP service with C(tailscale serve) under
    a C(svc:) name.
  - Creates an nginx virtual host at C(<domain>.prk.network) which only permits
    clients connecting from Tailscale address ranges.
options:
  name:
    description: Stable service name and C(svc:) name.
    required: true
    type: str
  domain:
    description:
      - DNS label used beneath C(prk.network).
      - Defaults to C(name).
    type: str
  local_port:
    description: Local port the service listens on.
    required: true
    type: int
  expose_ports:
    description:
      - Ports exposed by the native Tailscale Service.
      - Port 443 uses HTTPS; all other ports use HTTP.
    type: list
    elements: int
    default: [80, 443]
"""

EXAMPLES = r"""
- name: Expose purkhiser-bot internally
  internal_service:
    name: purkhiser-bot
    domain: bot
    local_port: 9090
"""

RETURN = r"""
changed:
  description: Whether the Tailscale Service or nginx virtual host changed.
  returned: always
  type: bool
"""

import json
import os
import re
import tempfile

from ansible.module_utils.basic import AnsibleModule


CONFIG_DIR = "/etc/nginx/internal-services.d"
NAME_PATTERN = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")


def serve_flag(expose_port):
    return (
        "--https={}".format(expose_port)
        if expose_port == 443
        else "--http={}".format(expose_port)
    )


def configure_tailscale(module, name, local_port, expose_ports):
    service = "svc:{}".format(name)
    expected = {
        "tcp:{}".format(port): "http://localhost:{}".format(local_port)
        for port in expose_ports
    }

    rc, stdout, _ = module.run_command(
        ["tailscale", "serve", "get-config", "--service={}".format(service)]
    )

    if rc == 0:
        try:
            current = json.loads(stdout).get("endpoints", {})
            if all(current.get(key) == value for key, value in expected.items()):
                return False
        except ValueError:
            pass

    if module.check_mode:
        return True

    for port in expose_ports:
        rc, _, stderr = module.run_command(
            [
                "tailscale",
                "serve",
                "--service={}".format(service),
                serve_flag(port),
                "localhost:{}".format(local_port),
            ]
        )
        if rc != 0:
            module.fail_json(
                msg="Failed to configure Tailscale Service port {}: {}".format(
                    port, stderr
                )
            )

    return True


def render_nginx_config(domain, local_port):
    return """server {{
    listen 443 ssl;
    server_name {domain}.prk.network;

    ssl_certificate     /var/lib/lego/certificates/prk.network.crt;
    ssl_certificate_key /var/lib/lego/certificates/prk.network.key;

    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;

    location / {{
        proxy_pass http://127.0.0.1:{local_port};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
    }}
}}
""".format(domain=domain, local_port=local_port)


def write_nginx_config(module, name, config):
    path = os.path.join(CONFIG_DIR, "{}.conf".format(name))

    try:
        with open(path, encoding="utf-8") as config_file:
            if config_file.read() == config:
                return False
    except FileNotFoundError:
        pass

    if module.check_mode:
        return True

    os.makedirs(CONFIG_DIR, mode=0o755, exist_ok=True)
    descriptor, temporary_path = tempfile.mkstemp(dir=CONFIG_DIR)

    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as config_file:
            config_file.write(config)
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, path)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)

    return True


def main():
    module = AnsibleModule(
        argument_spec=dict(
            name=dict(type="str", required=True),
            domain=dict(type="str"),
            local_port=dict(type="int", required=True),
            expose_ports=dict(type="list", elements="int", default=[80, 443]),
        ),
        supports_check_mode=True,
    )

    name = module.params["name"]
    if not NAME_PATTERN.fullmatch(name):
        module.fail_json(msg="name must be a valid lowercase DNS label")

    domain = module.params["domain"] or name
    if not NAME_PATTERN.fullmatch(domain):
        module.fail_json(msg="domain must be a valid lowercase DNS label")

    local_port = module.params["local_port"]
    if not 1 <= local_port <= 65535:
        module.fail_json(msg="local_port must be between 1 and 65535")

    expose_ports = module.params["expose_ports"]
    if any(not 1 <= port <= 65535 for port in expose_ports):
        module.fail_json(msg="expose_ports values must be between 1 and 65535")

    tailscale_changed = configure_tailscale(module, name, local_port, expose_ports)
    nginx_config = render_nginx_config(domain, local_port)
    nginx_changed = write_nginx_config(module, name, nginx_config)

    module.exit_json(changed=tailscale_changed or nginx_changed)


if __name__ == "__main__":
    main()
