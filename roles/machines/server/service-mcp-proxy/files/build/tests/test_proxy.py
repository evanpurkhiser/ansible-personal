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
