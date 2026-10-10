import json

import pytest
import fastmcp
from fastmcp.server.auth.oidc_proxy import OIDCConfiguration, OIDCProxy
from starlette.testclient import TestClient

import proxy


@pytest.fixture
def server(monkeypatch, tmp_path):
    key = tmp_path / "signing-key"
    key.write_bytes(b"a-secure-test-signing-key-of-at-least-32-bytes")
    monkeypatch.setattr(proxy, "Path", lambda _: key)
    monkeypatch.setattr(fastmcp.settings, "home", tmp_path)
    monkeypatch.setenv("MCP_USER_BACKENDS", "{}")
    monkeypatch.setenv("MCP_NAME", "example")
    monkeypatch.setenv("MCP_PUBLIC_URL", "https://apis.example.com/mcp/example")
    monkeypatch.setenv("OIDC_ISSUER", "https://id.example.com")
    monkeypatch.setenv("MCP_BACKEND", json.dumps({"url": "http://127.0.0.1:9000/mcp"}))
    config = OIDCConfiguration(
        issuer="https://id.example.com",
        authorization_endpoint="https://id.example.com/authorize",
        token_endpoint="https://id.example.com/token",
        jwks_uri="https://id.example.com/jwks",
        response_types_supported=["code"],
        subject_types_supported=["public"],
        id_token_signing_alg_values_supported=["RS256"],
    )
    monkeypatch.setattr(OIDCProxy, "get_oidc_configuration", lambda *a, **k: config)
    return proxy.create_server()


def test_unauthenticated_requests_advertise_the_resource(server):
    with TestClient(server.http_app(path="/")) as client:
        response = client.get("/")
        assert response.status_code == 401
        assert (
            "https://apis.example.com/.well-known/oauth-protected-resource/mcp/example/"
            in response.headers["www-authenticate"]
        )
        metadata = client.get(
            "/.well-known/oauth-protected-resource/mcp/example/"
        ).json()
        assert metadata["resource"] == "https://apis.example.com/mcp/example/"


def test_oauth_discovery_and_registration(server):
    with TestClient(server.http_app(path="/")) as client:
        metadata = client.get("/.well-known/oauth-authorization-server").json()
        assert metadata["issuer"] == "https://apis.example.com/mcp/example"
        assert "S256" in metadata["code_challenge_methods_supported"]
        assert (
            metadata["authorization_endpoint"]
            == "https://apis.example.com/mcp/example/authorize"
        )
        assert (
            metadata["registration_endpoint"]
            == "https://apis.example.com/mcp/example/register"
        )
        response = client.post(
            "/register",
            json={
                "redirect_uris": ["https://chatgpt.com/connector/oauth/callback"],
                "token_endpoint_auth_method": "none",
            },
        )
        assert response.status_code == 201
        assert response.json()["client_id"]


def test_stdio_credentials_are_isolated(monkeypatch):
    monkeypatch.setenv("MCP_NAME", "lunchmoney")
    monkeypatch.setenv(
        "MCP_USER_BACKENDS", '{"other": {"env": {"SECRET": "other-key"}}}'
    )
    monkeypatch.setenv("MCP_BACKEND", '{"env": {"SECRET": "other-key"}}')
    monkeypatch.setattr(proxy, "ProxyClient", lambda config, **kwargs: config)
    config = {"command": "lunchmoney-mcp", "env": {"SECRET": "selected-key"}}
    first = proxy.backend_client(config)
    second = proxy.backend_client(config)
    environment = first["mcpServers"]["lunchmoney"]["env"]
    assert environment["SECRET"] == "selected-key"
    assert "other-key" not in json.dumps(environment)
    assert first is not second
    assert config == {"command": "lunchmoney-mcp", "env": {"SECRET": "selected-key"}}


def test_users_route_to_their_own_backend(server, monkeypatch):
    from fastmcp.server.auth import AccessToken
    from fastmcp.server.providers.proxy import ProxyClient

    backends = {}
    for subject in ["evan-id", "vivian-id"]:
        backend = fastmcp.FastMCP(subject)
        backend.tool(lambda account=subject: account, name="account")
        backend.tool(lambda: "private", name=f"private_{subject}")
        backends[subject] = backend

    monkeypatch.setattr(
        proxy,
        "backend_client",
        lambda backend: ProxyClient(backends[backend["account"]]),
    )
    monkeypatch.setenv(
        "MCP_USER_BACKENDS",
        json.dumps({subject: {"account": subject} for subject in backends}),
    )
    routed = proxy.create_server()

    async def load_access_token(token):
        if token not in {"evan-id", "vivian-id", "unmapped-id"}:
            return None
        return AccessToken(
            token=token,
            client_id="test",
            scopes=["openid", "offline_access"],
            subject=token,
        )

    monkeypatch.setattr(routed.auth, "load_access_token", load_access_token)
    with TestClient(
        routed.http_app(path="/", stateless_http=True, json_response=True)
    ) as client:

        def call(subject):
            return client.post(
                "/",
                headers={
                    "Authorization": f"Bearer {subject}",
                    "Accept": "application/json, text/event-stream",
                },
                json={
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "tools/call",
                    "params": {"name": "account", "arguments": {}},
                },
            )

        for subject in ["evan-id", "vivian-id", "evan-id"]:
            listing = client.post(
                "/",
                headers={
                    "Authorization": f"Bearer {subject}",
                    "Accept": "application/json, text/event-stream",
                },
                json={"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
            ).json()
            assert {tool["name"] for tool in listing["result"]["tools"]} == {
                "account",
                f"private_{subject}",
            }
            response = call(subject)
            assert response.status_code == 200
            assert response.json()["result"]["content"][0]["text"] == subject

        denied = call("unmapped-id").json()
        assert "result" not in denied or denied["result"].get("isError")
        assert call("invalid-token").status_code == 401
