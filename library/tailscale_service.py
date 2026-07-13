#!/usr/bin/python

from __future__ import absolute_import, division, print_function

__metaclass__ = type

DOCUMENTATION = r"""
---
module: tailscale_service
short_description: Register a local HTTP service with tailscale serve
description:
  - Idempotently registers a local HTTP service with C(tailscale serve) so it
    is accessible on the Tailscale network under a C(svc:) name.
  - Checks the current config via C(tailscale serve get-config) and only
    calls C(tailscale serve) when the endpoints do not match.
options:
  name:
    description: Service name, without the C(svc:) prefix.
    required: true
    type: str
  local_port:
    description: Local port the service listens on.
    required: true
    type: int
  expose_ports:
    description: Ports exposed on the Tailscale network. 443 uses C(--https), all others use C(--http).
    type: list
    elements: int
    default: [80, 443]
"""

EXAMPLES = r"""
- name: Register purkhiser-bot as a tailscale service
  tailscale_service:
    name: purkhiser-bot
    local_port: 9090

- name: Register a service on a non-standard port only
  tailscale_service:
    name: my-service
    local_port: 8080
    expose_ports: [8080]
"""

RETURN = r"""
changed:
  description: Whether tailscale serve was called to update the config.
  returned: always
  type: bool
"""

import json

from ansible.module_utils.basic import AnsibleModule


def serve_flag(expose_port):
    return (
        "--https={}".format(expose_port)
        if expose_port == 443
        else "--http={}".format(expose_port)
    )


def check_and_configure(module, service, local_port, expose_ports):
    expected = {
        "tcp:{}".format(p): "http://localhost:{}".format(local_port)
        for p in expose_ports
    }

    rc, stdout, _ = module.run_command(
        ["tailscale", "serve", "get-config", "--service={}".format(service)]
    )

    if rc == 0:
        try:
            current = json.loads(stdout).get("endpoints", {})
            if all(current.get(k) == v for k, v in expected.items()):
                return False
        except ValueError:
            pass

    if module.check_mode:
        return True

    for p in expose_ports:
        rc, _, stderr = module.run_command(
            [
                "tailscale",
                "serve",
                "--service={}".format(service),
                serve_flag(p),
                "localhost:{}".format(local_port),
            ]
        )
        if rc != 0:
            module.fail_json(msg="Failed to configure tcp:{}: {}".format(p, stderr))

    return True


def main():
    module = AnsibleModule(
        argument_spec=dict(
            name=dict(type="str", required=True),
            local_port=dict(type="int", required=True),
            expose_ports=dict(type="list", elements="int", default=[80, 443]),
        ),
        supports_check_mode=True,
    )

    service = "svc:{}".format(module.params["name"])
    changed = check_and_configure(
        module, service, module.params["local_port"], module.params["expose_ports"]
    )
    module.exit_json(changed=changed)


if __name__ == "__main__":
    main()
