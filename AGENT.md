# Agent Guidelines

## Commit Message Style

Commits follow a scoped format:

```
scope(service): short description
```

- **scope**: the top-level role or area being changed (e.g. `server`, `common`, `paccache`, `aur`, `sudo`, `dots-manager`, `makesecrets`)
- **service**: the specific sub-component being changed (e.g. `hass`, `nginx`, `rclone`, `zfs`, `podman`, `transmission`, `atuin`); omit only when the change is generalized across the entire scope
- **description**: lowercase imperative phrase, no trailing period

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
