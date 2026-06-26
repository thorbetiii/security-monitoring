from __future__ import annotations

from datetime import datetime, timezone

from locust import HttpUser, between, task


PRODUCT_ID = "OLJCESPC7Z"


def checkout_payload() -> dict[str, str]:
    """Return a valid checkout form payload accepted by the frontend."""
    expiration_year = datetime.now(timezone.utc).year + 1

    return {
        "email": "automated-checkout@example.com",
        "street_address": "1600 Amphitheatre Parkway",
        "zip_code": "94043",
        "city": "Mountain View",
        "state": "CA",
        "country": "United States",
        "credit_card_number": "4432801561520454",
        "credit_card_expiration_month": "1",
        "credit_card_expiration_year": str(expiration_year),
        "credit_card_cvv": "672",
    }


class CheckoutAbuseUser(HttpUser):
    """
    Repeatedly completes valid checkout workflows using a persistent session.

    Each Locust user retains its own cookies. Therefore, five users should
    create approximately five stable attack sessions rather than a new
    session for every request.
    """

    wait_time = between(3, 5)

    def on_start(self) -> None:
        with self.client.get(
            "/",
            name="/ [checkout abuse session]",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(
                    f"Failed to initialize session: HTTP {response.status_code}"
                )

    @task
    def repeat_checkout(self) -> None:
        with self.client.get(
            f"/product/{PRODUCT_ID}",
            name="/product/[id] [checkout abuse]",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(
                    f"Product page failed: HTTP {response.status_code}"
                )
                return

        with self.client.post(
            "/cart",
            data={
                "product_id": PRODUCT_ID,
                "quantity": "1",
            },
            name="/cart [add item abuse]",
            allow_redirects=False,
            catch_response=True,
        ) as response:
            if response.status_code != 302:
                response.failure(
                    f"Add-to-cart expected HTTP 302, received "
                    f"{response.status_code}"
                )
                return

        with self.client.get(
            "/cart",
            name="/cart [view abuse]",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(
                    f"Cart page failed: HTTP {response.status_code}"
                )
                return

        with self.client.post(
            "/cart/checkout",
            data=checkout_payload(),
            name="/cart/checkout [abuse]",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(
                    f"Checkout failed: HTTP {response.status_code}"
                )