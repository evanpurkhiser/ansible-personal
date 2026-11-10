# Checkmk hardware monitoring spike

This role runs Checkmk Community in Podman and monitors the physical server with
the stock Checkmk Linux agent. The agent is served only on the Podman bridge and
is unreachable from the LAN, WAN, and tailnet.

The host packages provide the hardware data sources:

- FreeIPMI exposes BMC sensor state, including fans, temperatures, voltages,
  power supplies, and chassis faults.
- smartmontools and the stock asynchronous SMART plug-in expose disk health.
- The stock agent reports filesystems, memory, load, systemd services, and ZFS.

The first run creates the `monitoring` site, installs the matching agent from
that site, creates the `server` host through Checkmk's REST API, discovers its
services, and activates the resulting configuration. The UI is available at
`https://checkmk.prk.network/monitoring/` with the `cmkadmin` user.

Add the real password to `vars/secrets.yml` before applying the role:

```yaml
checkmk:
  admin_password: "..."
```

Run the role with:

```console
ansible-playbook play-server.yml --tags checkmk
```

## Notification rule

The role installs a `Purkhiser Bot` notification method inside the site. Add a
notification rule under **Setup > Events > Notifications** that selects this
method for host and service state changes. It posts to the System Notices
channel through the existing local bot service.

Checkmk runs on the machine it monitors, so it can report degraded hardware
while the OS and network remain alive. Complete host, power, or internet loss
requires an external availability monitor.
