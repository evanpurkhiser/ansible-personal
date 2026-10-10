import json
import os
from pathlib import Path

from fastmcp.server import create_proxy
from fastmcp.server.auth.oidc_proxy import OIDCProxy
from fastmcp.server.providers.proxy import ProxyClient


def create_server():
    backend = json.loads(os.environ["MCP_BACKEND"])
    if "command" in backend:
        backend["env"] = dict(os.environ)
        backend["keep_alive"] = False

    backend = {"mcpServers": {os.environ["MCP_NAME"]: backend}}

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
    return create_proxy(
        ProxyClient(backend, forward_incoming_headers=False),
        name=os.environ["MCP_NAME"],
        auth=auth,
    )


if __name__ == "__main__":
    create_server().run(
        transport="http", host="127.0.0.1", port=int(os.environ["PORT"]), path="/"
    )
