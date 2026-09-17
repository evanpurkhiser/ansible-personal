#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["PyJWT[crypto]==2.14.0"]
# ///
"""Authorize GitHub publishing workflows to request Podman auto-update."""

import json
import logging
import queue
import re
import subprocess
import threading
from collections.abc import Mapping
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import NotRequired, TypedDict, cast

import jwt

ISSUER = "https://token.actions.githubusercontent.com"
AUDIENCE = "https://apis.evanpurkhiser.com/deploy-image"
WORKFLOW = "evanpurkhiser/workflows/.github/workflows/deploy-image-personal.yml@refs/heads/main"
MAX_BODY = 16384


class IdentityClaims(TypedDict):
    repository: str
    run_id: str
    sha: NotRequired[str]
    run_attempt: NotRequired[str]


class DeploymentRequest(TypedDict):
    repository: str
    image: str
    trigger_digest: str
    commit_sha: str | None
    run_id: str
    run_attempt: str | None


class ContainerSnapshot(TypedDict):
    name: str
    image: str
    image_id: str
    manifest_digest: str
    state: str


type ImageSnapshots = dict[str, ContainerSnapshot]


def verify_identity(token: str, keys: jwt.PyJWKClient) -> IdentityClaims:
    claims = jwt.decode(
        token,
        keys.get_signing_key_from_jwt(token).key,
        algorithms=["RS256"],
        issuer=ISSUER,
        audience=AUDIENCE,
        options={
            "require": [
                "exp",
                "iat",
                "nbf",
                "sub",
                "repository",
                "repository_owner",
                "repository_owner_id",
                "ref",
                "event_name",
                "job_workflow_ref",
                "run_id",
            ],
        },
    )
    expected = {
        "repository_owner": "evanpurkhiser",
        "repository_owner_id": "1421724",
        "ref": "refs/heads/main",
        "event_name": "push",
        "job_workflow_ref": WORKFLOW,
    }
    if any(claims.get(key) != value for key, value in expected.items()):
        raise ValueError("Workflow identity is not authorized")

    for key in ("repository", "run_id", "sha", "run_attempt"):
        if key in claims and not isinstance(claims[key], str):
            raise ValueError(f"Expected a string claim: {key}")

    if not re.fullmatch(r"evanpurkhiser/[A-Za-z0-9_.-]+", claims["repository"]):
        raise ValueError("Repository is not authorized")

    return cast(IdentityClaims, claims)


def has_eligible_container(image: str) -> bool:
    result = subprocess.run(
        [
            "/usr/bin/podman",
            "ps",
            "--filter",
            "label=io.containers.autoupdate=registry",
            "--format",
            "{{.Image}}",
        ],
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    )
    return image in result.stdout.splitlines()


def deployment_request(
    body: Mapping[str, object], claims: IdentityClaims
) -> DeploymentRequest:
    image = f"ghcr.io/{claims['repository']}:latest"
    digest = body.get("digest")
    if body.get("image") != image:
        raise ValueError("Image must match the authenticated repository")

    if not isinstance(digest, str) or not re.fullmatch(r"sha256:[a-f0-9]{64}", digest):
        raise ValueError("Expected a SHA-256 image digest")

    return {
        "repository": claims["repository"],
        "image": image,
        "trigger_digest": digest,
        "commit_sha": claims.get("sha"),
        "run_id": claims["run_id"],
        "run_attempt": claims.get("run_attempt"),
    }


def snapshot_images(image: str) -> ImageSnapshots:
    names = subprocess.run(
        ["/usr/bin/podman", "ps", "--all", "--format", "{{.Names}}"],
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    ).stdout.splitlines()
    if not names:
        return {}

    # Inspect the container's actual image, even when its mutable tag has moved.
    template = (
        '{"name":{{json .Name}},"image":{{json .ImageName}},'
        '"image_id":{{json .Image}},"manifest_digest":{{json .ImageDigest}},'
        '"state":{{json .State.Status}}}'
    )
    result = subprocess.run(
        ["/usr/bin/podman", "container", "inspect", "--format", template, *names],
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    )
    containers = [
        cast(ContainerSnapshot, json.loads(line)) for line in result.stdout.splitlines()
    ]
    return {c["name"]: c for c in containers if c["image"] == image}


def update_images(request: DeploymentRequest) -> None:
    # The trigger digest is reporting context; deployment follows latest.
    # Auto-update checks every eligible container, while these snapshots cover
    # containers using the requested image. A successful systemd invocation
    # reports service completion; application readiness and rollback depend on
    # Podman's readiness and rollback configuration.
    before = snapshot_images(request["image"])
    logging.info("Deployment starting: %s", json.dumps(request | {"before": before}))
    succeeded = False

    try:
        # Both the timer and webhook start the same unit; systemd joins
        # concurrent starts of the auto-update service.
        subprocess.run(
            ["/usr/bin/systemctl", "start", "podman-auto-update.service"],
            check=True,
        )
        succeeded = True
    except (subprocess.SubprocessError, OSError):
        logging.exception("Podman auto-update failed; see its service journal")

    after: ImageSnapshots | None
    try:
        after = snapshot_images(request["image"])
    except (subprocess.SubprocessError, OSError, ValueError):
        logging.exception("Could not capture images after auto-update")
        after = None

    report: dict[str, object] = {
        **request,
        "update_service_succeeded": succeeded,
        "before": before,
        "after": after,
    }
    logging.info("Deployment result: %s", json.dumps(report))


def update_worker(pending: queue.Queue[DeploymentRequest]) -> None:
    while True:
        request = pending.get()

        try:
            update_images(request)
        except (subprocess.SubprocessError, OSError, ValueError):
            logging.exception("Deployment failed: %s", json.dumps(request))
        finally:
            pending.task_done()


class Handler(BaseHTTPRequestHandler):
    server: "DeploymentServer"

    def setup(self) -> None:
        super().setup()
        self.connection.settimeout(15)

    def do_POST(self) -> None:
        if self.path != "/deploy-image":
            self.respond(404, "Unknown route")
            return

        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.respond(400, "Invalid content length")
            return

        if not 0 < size <= MAX_BODY or self.headers.get("Transfer-Encoding"):
            self.respond(400, "Expected a bounded JSON request body")
            return

        try:
            body: object = json.loads(self.rfile.read(size))
            if not isinstance(body, dict):
                raise ValueError("Expected an object")
        except (ValueError, TimeoutError):
            self.respond(400, "Invalid JSON request body")
            return

        try:
            scheme, token = self.headers.get("Authorization", "").split(" ", 1)
            if scheme != "Bearer":
                raise ValueError("Bearer token required")

            claims = verify_identity(token, self.server.keys)
        except jwt.PyJWKClientConnectionError:
            self.respond(503, "GitHub signing keys unavailable")
            return
        except (ValueError, TypeError, jwt.PyJWTError):
            self.respond(403, "Unauthorized workflow identity")
            return

        try:
            request = deployment_request(body, claims)
        except ValueError as error:
            self.respond(400, str(error))
            return

        try:
            eligible = has_eligible_container(request["image"])
        except (subprocess.SubprocessError, OSError):
            logging.exception("Could not discover eligible containers")
            self.respond(503, "Container discovery unavailable")
            return

        if not eligible:
            self.respond(403, "Repository has no eligible container")
            return

        try:
            self.server.pending.put_nowait(request)
        except queue.Full:
            self.respond(503, "Image update queue is full; retry later")
            return

        logging.info("Accepted deployment: %s", json.dumps(request))
        self.respond(202, "Image update requested")

    def respond(self, status: int, message: str) -> None:
        body = json.dumps({"message": message}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class DeploymentServer(HTTPServer):
    def __init__(self, address: tuple[str, int], keys: jwt.PyJWKClient) -> None:
        self.keys = keys
        self.pending: queue.Queue[DeploymentRequest] = queue.Queue(maxsize=64)
        super().__init__(address, Handler)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    keys = jwt.PyJWKClient(f"{ISSUER}/.well-known/jwks", timeout=10)
    server = DeploymentServer(("127.0.0.1", 19090), keys)
    threading.Thread(target=update_worker, args=(server.pending,), daemon=True).start()
    server.serve_forever()


if __name__ == "__main__":
    main()
