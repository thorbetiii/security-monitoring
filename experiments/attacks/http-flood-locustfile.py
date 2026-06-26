from __future__ import annotations

from urllib.parse import urlparse

from locust import HttpUser, constant_throughput, events, task


ALLOWED_TARGETS = {
    "localhost",
    "127.0.0.1",
    "::1",
}


@events.test_start.add_listener
def restrict_target(environment, **kwargs) -> None:
    """Restrict this experiment to the local thesis environment."""
    target = environment.host or ""
    hostname = urlparse(target).hostname

    if hostname not in ALLOWED_TARGETS:
        raise RuntimeError(
            "HTTP flood experiment is restricted to localhost. "
            f"Refusing target: {target!r}"
        )


class ControlledHttpFloodUser(HttpUser):
    """
    Generates sustained traffic against valid application routes.

    Each user attempts approximately one request per second. The total
    intensity is therefore controlled through the Locust user count.
    """

    wait_time = constant_throughput(1.0)

    def send_request(self, path: str) -> None:
        with self.client.get(
            path,
            name="/[valid-flood-target]",
            allow_redirects=True,
            catch_response=True,
        ) as response:
            if response.status_code < 500:
                response.success()
            else:
                response.failure(
                    f"Server error for {path}: HTTP {response.status_code}"
                )

    @task(5)
    def request_product(self) -> None:
        self.send_request("/product/OLJCESPC7Z")

    @task(3)
    def request_homepage(self) -> None:
        self.send_request("/")

    @task(2)
    def request_cart(self) -> None:
        self.send_request("/cart")
