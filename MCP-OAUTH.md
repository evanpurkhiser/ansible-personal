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

Pocket ID generates a persistent administrative API key at
`/etc/pocket-id/api-key`. MCP roles read it on the server when registering their
OIDC clients. Apply with `--tags nginx,pocket-id,mcp`.

Services can set `mcp_proxy_user_backends` keyed by Pocket ID username. Each
entry merges with `mcp_proxy_backend`. The proxy requests the `profile` scope
and selects a backend from the verified token's `preferred_username` claim.
Missing or unmapped usernames are denied. Each request opens an isolated backend
session; stdio processes receive only their selected credentials.

Lunch Money uses `/mcp/lunchmoney/` for both users, with `evan` and `vivian`
selecting their respective API tokens.

Home Assistant's backend remains on its existing loopback endpoint at port 9584.
Jellyfin and Lunch Money launch their stdio backends in the proxy container.

Back up Pocket ID's data and encryption key together, and each MCP proxy's data
and signing key together.

## Migration

During cutover, stop and remove the old tunnel containers, generated units,
images, and tunnel configuration files. After applying, validate passkey login,
refresh, tool calls, restart persistence, and rejection of a token from another
MCP endpoint.
