#!/usr/bin/python

from __future__ import absolute_import, division, print_function

__metaclass__ = type

DOCUMENTATION = r"""
---
module: internal_service
short_description: Expose a local HTTP service through nginx
description:
  - Creates an nginx virtual host at C(<domain>.prk.network) that only permits
    clients connecting from Tailscale address ranges.
options:
  name:
    description: Stable service name used for the nginx configuration filename.
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
  description: Whether the nginx virtual host changed.
  returned: always
  type: bool
"""

import os
import re
import tempfile

from ansible.module_utils.basic import AnsibleModule


CONFIG_DIR = "/etc/nginx/internal-services.d"
NAME_PATTERN = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")


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

    nginx_config = render_nginx_config(domain, local_port)
    nginx_changed = write_nginx_config(module, name, nginx_config)

    module.exit_json(changed=nginx_changed)


if __name__ == "__main__":
    main()
