# Agent Guidelines

## Commit Message Style

Commits follow a scoped format:

```
scope(service): short description
```

- **scope**: the top-level role or area being changed (e.g. `server`, `common`, `paccache`, `aur`, `sudo`, `dots-manager`, `makesecrets`)
- **service**: the specific sub-component being changed (e.g. `hass`, `nginx`, `rclone`, `zfs`, `podman`, `transmission`, `atuin`); omit only when the change is generalized across the entire scope
- **description**: imperative phrase, capitalized first word, no trailing period

### Examples

```
server(hass): Add lunchmoney unreviewed sensor
server(nginx): Switch from public proxy to Tailscale-only access
server(zrepl): Push hourly snapshots to offsite NAS with tiered retention
server: Split monolithic role into machines/server/main + service-* roles
makesecrets: Fix Doppovich bot token field name
dots-manager: Fix path for permissions update
paccache: Add paccache role
```

### Rules

- Omit `(service)` only when the change is generalized across the entire scope, not targeting a specific sub-component
- Keep the description concise — one short phrase
- Use imperative mood ("Add", "Fix", "Remove", "Update", "Switch", not "Added" or "Adds")
- Capitalize the first word of the description; the rest follows normal sentence case

---

## Applying the Playbook

Install Galaxy dependencies (one-time):

```sh
ansible-galaxy install -r requirements.yml
```

Apply the full playbook:

```sh
ansible-playbook play-server.yml
```

Apply only a specific service using tags (preferred when changing a single role):

```sh
ansible-playbook play-server.yml --tags hass
ansible-playbook play-server.yml --tags nginx,zrepl
```

Available tags: `zfs`, `packages`, `sshd`, `network`, `hardware`, `pam-ssh-agent`, `nfs`, `tailscale`, `nginx`, `transmission`, `hass`, `waitress`, `meal-log`, `instagram-saver`, `venmo-auto-cashout`, `venmo-lunchmoney-ai`, `atuin`, `podman-auto-update`, `zrepl`, `record-file-history`, `purkhiser-bot`, `weekly-report`, `speedtest-monitor`, `auto-system-update`, `bambulab-lights-off`, `opencode`, `clean-macfiles`

---

## Secrets

Secrets live in `vars/secrets.yml`, which is gitignored and never committed. Generate it by running:

```sh
./makesecrets.sh
```

This requires the 1Password CLI (`op`) to be authenticated. The `common` role will run this automatically if the file doesn't exist yet.

---

## Writing Roles

### Task conventions

- Every task must have a `name:` field
- Task names use natural language sentence style: `"Ensure hass configuration"`, `"Install venmo-auto-cashout config"`, `"Enable pacsync timer service"`
- Common name verbs: `Ensure`, `Install`, `Enable`, `Add`, `Create`, `Configure`, `Set`, `Override`
- Always use fully qualified collection names (FQCN): `ansible.builtin.copy`, `community.general.pacman`, `containers.podman.podman_container`, `kewlfft.aur.aur`, etc. ansible-lint enforces this.

### Service role layout

New service roles go under `roles/machines/server/service-<name>/` and follow this structure:

```
service-<name>/
├── tasks/
│   └── main.yml        # Required
├── files/              # Static files (systemd units, scripts, configs)
├── templates/          # Jinja2 templates (when secrets/vars need interpolation)
└── handlers/
    └── main.yml        # Service restart/reload handlers
```

The role must be imported with a tag in `roles/machines/server/main/tasks/main.yml`.

### Config file pattern

Services that need secrets write a `/etc/<service-name>.conf` env file (mode `0600`) sourced by systemd, using Jinja2 to inject secret values.

### Podman container pattern

Use `containers.podman.podman_container` with `generate_systemd:` to emit a systemd unit, and `label: io.containers.autoupdate: registry` for auto-update eligibility. Follow with an `ansible.builtin.systemd` task to start and enable `container-<name>`.

