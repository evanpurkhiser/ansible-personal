import json
import os
from pathlib import Path

from fastmcp import FastMCP
from fastmcp.server import create_proxy
from fastmcp.server.auth.oidc_proxy import OIDCProxy
from fastmcp.server.dependencies import get_access_token
from fastmcp.server.providers.proxy import ProxyClient, ProxyProvider
from mcp import MCPError
from mcp.types import ErrorData


def backend_client(backend):
    if "command" in backend:
        # The child process receives only its selected account's credentials.
        environment = {
            key: value
            for key, value in os.environ.items()
            if key not in {"MCP_BACKEND", "MCP_USER_BACKENDS"}
        }
        backend = backend | {
            "env": environment | backend.get("env", {}),
            "keep_alive": False,
        }

    return ProxyClient(
        {"mcpServers": {os.environ["MCP_NAME"]: backend}},
        forward_incoming_headers=False,
    )


def user_client_factory(backends):
    def client():
        token = get_access_token()
        backend = backends.get(token.subject) if token else None
        if backend is None:
            raise MCPError(
                ErrorData(code=-32000, message="No MCP backend for this user")
            )

        return backend_client(backend)

    return client


def create_server():
    backend = json.loads(os.environ["MCP_BACKEND"])
    user_backends = json.loads(os.environ.get("MCP_USER_BACKENDS", "{}"))

    # Pocket ID authenticates the user; FastMCP issues audience-bound MCP tokens.
    auth = OIDCProxy(
        config_url=f"{os.environ['OIDC_ISSUER']}/.well-known/openid-configuration",
        client_id=f"mcp-{os.environ['MCP_NAME']}",
        base_url=os.environ["MCP_PUBLIC_URL"],
        jwt_signing_key=Path("/run/secrets/signing-key").read_bytes(),
        token_endpoint_auth_method="none",
        required_scopes=["openid", "offline_access"],
        verify_id_token=True,
        forward_resource=False,
    )
    if user_backends:
        return FastMCP(
            name=os.environ["MCP_NAME"],
            auth=auth,
            # Backend catalogs can differ by user; do not share cached listings.
            providers=[ProxyProvider(user_client_factory(user_backends), cache_ttl=0)],
        )

    return create_proxy(
        backend_client(backend),
        name=os.environ["MCP_NAME"],
        auth=auth,
    )


if __name__ == "__main__":
    create_server().run(
        transport="http", host="127.0.0.1", port=int(os.environ["PORT"]), path="/"
    )
