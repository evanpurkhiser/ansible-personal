# Private MCP services

Each MCP service imports `machines/server/service-mcp-proxy` with its name, port,
backend connection, and any backend credentials. The shared role manages a
FastMCP OIDC proxy, Pocket ID client registration, systemd, and a public nginx
route at `https://apis.evanpurkhiser.com/mcp/<name>/`.

Pocket ID authenticates users with a public PKCE client. FastMCP validates the
upstream ID token and issues its own audience-bound MCP access tokens. Each
proxy persists its signing key and encrypted OAuth state across restarts.
Backend credentials stay in the service's root-readable environment file.

## Deployment prerequisites

Create an administrative Pocket ID API key, save it in the Private vault's
Pocket ID item as `API key`, and regenerate the local Ansible secrets. Create
`mcp-admin` containing Evan and `mcp-shared` containing Evan and Vivian. The
Lunch Money endpoint allows `mcp-shared`; the other endpoints allow
`mcp-admin`.

Services can set `mcp_proxy_user_backends` keyed by Pocket ID username. Ansible
resolves usernames to stable user IDs and merges each entry with
`mcp_proxy_backend`. The proxy selects a backend from the verified token's
subject and denies unmapped users. Each request opens an isolated backend
session; stdio processes receive only their selected credentials.

Lunch Money uses `/mcp/lunchmoney/` for both users, with `evan` and `vivian`
selecting their respective API tokens.

Home Assistant's backend remains on its existing loopback endpoint at port 9584.
Jellyfin and Lunch Money launch their stdio backends in the proxy container.

Back up Pocket ID's data and encryption key together, and each MCP proxy's data
and signing key together.

## Migration

Before applying, validate the client registration and passkey login against the
installed Pocket ID version, including restart persistence, refresh, tool calls,
and rejection of a token from another MCP endpoint. Then stop and remove the
old tunnel containers, generated units, images, and tunnel configuration files
as a one-time migration operation.
