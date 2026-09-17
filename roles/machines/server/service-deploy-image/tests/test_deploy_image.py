import http.client
import importlib.util
import json
import subprocess
import threading
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa

spec = importlib.util.spec_from_file_location(
    "deploy_image", Path(__file__).parents[1] / "files" / "deploy-image.py"
)
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)


class DeploymentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.keys = SimpleNamespace(
            get_signing_key_from_jwt=lambda token: SimpleNamespace(
                key=cls.private_key.public_key()
            )
        )

    def setUp(self):
        now = int(time.time())
        self.claims = {
            "iss": deploy.ISSUER,
            "aud": deploy.AUDIENCE,
            "exp": now + 300,
            "iat": now,
            "nbf": now - 60,
            "sub": "repo:evanpurkhiser/waitress:ref:refs/heads/main",
            "repository": "evanpurkhiser/waitress",
            "repository_owner": "evanpurkhiser",
            "repository_owner_id": "1421724",
            "ref": "refs/heads/main",
            "event_name": "push",
            "job_workflow_ref": deploy.WORKFLOW,
            "run_id": "1234",
        }

    def token(self, **overrides):
        return jwt.encode(self.claims | overrides, self.private_key, algorithm="RS256")

    def test_github_identity_verified(self):
        claims = deploy.verify_identity(self.token(), self.keys)
        self.assertEqual(claims["repository"], "evanpurkhiser/waitress")

    def test_rejects_invalid_claims(self):
        cases = [
            {"aud": "another-service"},
            {"iss": "https://attacker.example"},
            {"exp": int(time.time()) - 60},
            {"repository_owner_id": "9999"},
            {"repository": "someone-else/waitress"},
            {"repository": 123},
            {"run_id": 123},
            {"sha": None},
            {"run_attempt": 1},
            {"ref": "refs/heads/feature"},
            {"event_name": "pull_request_target"},
            {
                "job_workflow_ref": "evanpurkhiser/waitress/.github/workflows/main.yml@refs/heads/main"
            },
        ]
        for overrides in cases:
            with self.subTest(overrides=overrides):
                with self.assertRaises((ValueError, jwt.PyJWTError)):
                    deploy.verify_identity(self.token(**overrides), self.keys)

    def test_rejects_forged_signature(self):
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        token = jwt.encode(self.claims, key, algorithm="RS256")
        with self.assertRaises(jwt.InvalidSignatureError):
            deploy.verify_identity(token, self.keys)

    def request(self, token, eligible=True, body=None):
        server = deploy.DeploymentServer(("127.0.0.1", 0), self.keys)
        thread = threading.Thread(target=server.handle_request)
        thread.start()
        connection = http.client.HTTPConnection(*server.server_address, timeout=5)
        try:
            with patch.object(
                deploy, "has_eligible_container", return_value=eligible
            ) as lookup:
                connection.request(
                    "POST",
                    "/deploy-image",
                    body=json.dumps(
                        body
                        if body is not None
                        else {
                            "image": "ghcr.io/evanpurkhiser/waitress:latest",
                            "digest": "sha256:" + "a" * 64,
                        }
                    ),
                    headers={
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json",
                    },
                )
                response = connection.getresponse()
                response.read()
                thread.join(timeout=5)
                return response.status, not server.pending.empty(), lookup.call_args
        finally:
            connection.close()
            server.server_close()

    def test_authorizes_from_claims_and_queues(self):
        status, pending, lookup = self.request(self.token())
        self.assertEqual(status, 202)
        self.assertTrue(pending)
        self.assertEqual(lookup.args, ("ghcr.io/evanpurkhiser/waitress:latest",))

    def test_rejects_repository_without_opt_in(self):
        status, pending, _ = self.request(self.token(), eligible=False)
        self.assertEqual(status, 403)
        self.assertFalse(pending)

    def test_rejects_missing_token(self):
        status, pending, lookup = self.request("")
        self.assertEqual(status, 403)
        self.assertFalse(pending)
        self.assertIsNone(lookup)

    def test_rejects_invalid_deployment_payload(self):
        for body in [
            {"image": "ghcr.io/attacker/other:latest", "digest": "sha256:" + "a" * 64},
            {"image": "ghcr.io/evanpurkhiser/waitress:latest"},
            {"image": "ghcr.io/evanpurkhiser/waitress:latest", "digest": "git-sha"},
        ]:
            with self.subTest(body=body):
                status, pending, lookup = self.request(self.token(), body=body)
                self.assertEqual(status, 400)
                self.assertFalse(pending)
                self.assertIsNone(lookup)

    def test_reports_trigger_and_actual_images_even_after_failure(self):
        request = deploy.deployment_request(
            {
                "image": "ghcr.io/evanpurkhiser/waitress:latest",
                "digest": "sha256:" + "a" * 64,
            },
            self.claims,
        )
        before = {"waitress": {"image_id": "old", "manifest_digest": "old-digest"}}
        after = {"waitress": {"image_id": "new", "manifest_digest": "new-digest"}}
        for error in [None, subprocess.CalledProcessError(1, "systemctl")]:
            with self.subTest(error=error):
                with (
                    patch.object(
                        deploy, "snapshot_images", side_effect=[before, after]
                    ),
                    patch.object(deploy.subprocess, "run", side_effect=error),
                    self.assertLogs(level="INFO") as logs,
                ):
                    deploy.update_images(request)
                report = json.loads(logs.output[-1].split("Deployment result: ", 1)[1])
                self.assertEqual(report["trigger_digest"], request["trigger_digest"])
                self.assertEqual(report["before"], before)
                self.assertEqual(report["after"], after)
                self.assertEqual(report["update_service_succeeded"], error is None)

    def test_authorization_requires_exact_configured_image(self):
        with patch.object(
            deploy.subprocess,
            "run",
            return_value=SimpleNamespace(
                stdout="ghcr.io/evanpurkhiser/waitress:latest\n"
            ),
        ):
            self.assertTrue(
                deploy.has_eligible_container("ghcr.io/evanpurkhiser/waitress:latest")
            )
            self.assertFalse(
                deploy.has_eligible_container(
                    "ghcr.io/evanpurkhiser/waitress-other:latest"
                )
            )
            self.assertFalse(
                deploy.has_eligible_container("ghcr.io/evanpurkhiser/waitress:dev")
            )

    def test_snapshot_reads_actual_container_images(self):
        containers = [
            {
                "name": "server",
                "image": "ghcr.io/example/app:latest",
                "image_id": "old",
            },
            {
                "name": "worker",
                "image": "ghcr.io/example/app:latest",
                "image_id": "old",
            },
            {"name": "database", "image": "postgres:17", "image_id": "other"},
        ]
        with patch.object(
            deploy.subprocess,
            "run",
            side_effect=[
                SimpleNamespace(stdout="server\nworker\ndatabase\n"),
                SimpleNamespace(stdout="\n".join(json.dumps(c) for c in containers)),
            ],
        ):
            snapshot = deploy.snapshot_images("ghcr.io/example/app:latest")
        self.assertEqual(set(snapshot), {"server", "worker"})
        self.assertEqual(snapshot["server"]["image_id"], "old")


if __name__ == "__main__":
    unittest.main()
