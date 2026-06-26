from __future__ import annotations

import random
from urllib.parse import urlparse

from locust import HttpUser, between, events, task


# The scanner is intentionally restricted to the local thesis environment.
ALLOWED_TARGETS = {
    "localhost",
    "127.0.0.1",
    "::1",
}


# Deterministic reconnaissance path set.
# All requests are GET requests and should not modify application state.
SCAN_PATHS = [
    "/admin",
    "/administrator",
    "/admin/login",
    "/login",
    "/signin",
    "/auth",
    "/dashboard",
    "/console",
    "/manage",
    "/management",
    "/api",
    "/api/v1",
    "/api/v2",
    "/api/internal",
    "/graphql",
    "/graphiql",
    "/swagger",
    "/swagger-ui",
    "/swagger-ui/index.html",
    "/openapi.json",
    "/api-docs",
    "/metrics",
    "/prometheus",
    "/debug",
    "/debug/pprof",
    "/health",
    "/healthz",
    "/ready",
    "/actuator",
    "/actuator/health",
    "/actuator/env",
    "/server-status",
    "/status",
    "/.env",
    "/.git/config",
    "/.git/HEAD",
    "/config",
    "/config.json",
    "/settings.json",
    "/backup",
    "/backup.zip",
    "/database.sql",
    "/dump.sql",
    "/robots.txt",
    "/sitemap.xml",
    "/wp-admin",
    "/wp-login.php",
    "/phpinfo.php",
    "/vendor",
    "/node_modules",
    "/internal",
    "/private",
    "/secret",
    "/test",
    "/dev",
    "/staging",
    "/old",
    "/tmp",
    "/uploads",
    "/files",
]


@events.test_start.add_listener
def enforce_local_target(environment, **kwargs) -> None:
    """Abort immediately if the target is not the local thesis system."""
    target = environment.host or ""
    hostname = urlparse(target).hostname

    if hostname not in ALLOWED_TARGETS:
        raise RuntimeError(
            "Endpoint scanning is restricted to localhost/127.0.0.1. "
            f"Refusing target: {target!r}"
        )


class ControlledEndpointScanner(HttpUser):
    """
    Simulates an unauthenticated client enumerating application endpoints.

    The scanner uses a moderate request rate and many distinct paths. Its goal
    is behavioural reconnaissance detection, not resource exhaustion.
    """

    wait_time = between(0.35, 0.70)

    def on_start(self) -> None:
        # Give each virtual user a different starting position.
        self.path_index = random.randrange(len(SCAN_PATHS))

    @task
    def probe_endpoint(self) -> None:
        path = SCAN_PATHS[self.path_index % len(SCAN_PATHS)]
        self.path_index += 1

        with self.client.get(
            path,
            name="/[reconnaissance-path]",
            allow_redirects=False,
            catch_response=True,
        ) as response:
            # 2xx, 3xx, 4xx are valid scanning outcomes.
            # Only server-side 5xx behaviour counts as a failed test request.
            if response.status_code < 500:
                response.success()
            else:
                response.failure(
                    f"Server error while scanning {path}: "
                    f"HTTP {response.status_code}"
                )