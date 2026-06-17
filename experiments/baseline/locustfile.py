from locust import HttpUser, between, task


class NormalShopper(HttpUser):
    """Simulates light, normal browsing behaviour."""

    wait_time = between(2, 5)

    @task(5)
    def view_homepage(self) -> None:
        self.client.get("/", name="/")

    @task(4)
    def view_product(self) -> None:
        self.client.get(
            "/product/OLJCESPC7Z",
            name="/product/[product_id]",
        )

    @task(2)
    def view_cart(self) -> None:
        self.client.get("/cart", name="/cart")