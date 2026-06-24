from datetime import datetime

from locust import HttpUser, between, task


PRODUCT_ID = "OLJCESPC7Z"


class NormalCheckoutShopper(HttpUser):
    """
    Simulates ordinary browsing with occasional successful checkout activity.

    Each Locust user retains its own cookie-based session, allowing cart and
    checkout activity to be associated with a consistent frontend session ID.
    """

    wait_time = between(4, 10)

    def on_start(self) -> None:
        self.client.get("/", name="/")

    @task(10)
    def view_homepage(self) -> None:
        self.client.get("/", name="/")

    @task(8)
    def view_product(self) -> None:
        self.client.get(
            f"/product/{PRODUCT_ID}",
            name="/product/[product_id]",
        )

    @task(5)
    def view_cart(self) -> None:
        self.client.get("/cart", name="/cart")

    @task(1)
    def complete_checkout(self) -> None:
        # Add a valid item to the current user's cart.
        with self.client.post(
            "/cart",
            data={
                "product_id": PRODUCT_ID,
                "quantity": "1",
            },
            name="/cart [add item]",
            allow_redirects=True,
            catch_response=True,
        ) as response:
            if response.status_code >= 400:
                response.failure(
                    f"Add-to-cart failed with HTTP {response.status_code}"
                )
                return

        # Submit a valid order using mock test data.
        expiration_year = datetime.now().year + 1

        with self.client.post(
            "/cart/checkout",
            data={
                "email": "normal.user@example.com",
                "street_address": "123 Baseline Street",
                "zip_code": "10000",
                "city": "Hanoi",
                "state": "Hanoi",
                "country": "Vietnam",
                "credit_card_number": "4111111111111111",
                "credit_card_expiration_month": "12",
                "credit_card_expiration_year": str(expiration_year),
                "credit_card_cvv": "123",
            },
            name="/cart/checkout",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(
                    f"Checkout failed with HTTP {response.status_code}"
                )