# Security Monitoring for Microservice Environments

Implementation environment for the bachelor thesis project:

**Enhancing Security Monitoring in Microservice Environments Using AI-Driven Operations**

This repository uses a reduced version of Google Online Boutique as the target microservice application for security monitoring experiments. The current scope keeps only the services required for browsing, cart, checkout, payment, shipping, currency conversion, and email confirmation.

## Current Scope

The project is organized around two runtime areas:

- `application`: reduced Online Boutique application
- `monitoring`: observability, logging, alerting, and detection components

The reduced application is intentionally smaller than the original Online Boutique demo so thesis experiments can focus on security monitoring signals rather than optional demo features.

## Application Services

The active application services are:

- `frontend`
- `productcatalogservice`
- `cartservice`
- `redis-cart`
- `checkoutservice`
- `paymentservice`
- `shippingservice`
- `currencyservice`
- `emailservice`

The following original demo services are removed from the main thesis implementation:

- `adservice`
- `recommendationservice`
- `loadgenerator`

Traffic generation is handled separately through custom scripts or Locust so experiment traffic can be controlled explicitly.

## Deployment

### Docker Compose

The root-level [docker-compose.yml](./docker-compose.yml) runs the reduced application locally.

Build the service images:

```bash
docker compose build
```

Start the application:

```bash
docker compose up -d
```

Check container status:

```bash
docker compose ps
```

Open the frontend:

```text
http://localhost:8080
```

Stop the application:

```bash
docker compose down
```

### Kubernetes

Kubernetes manifests are kept under [application/manifests](./application/manifests).

Create namespaces:

```bash
kubectl apply -f application/manifests/namespaces.yaml
```

Deploy the reduced application:

```bash
kubectl apply -f application/manifests/application-reduced.yaml
```

Check application pods:

```bash
kubectl get pods -n application
```

## Monitoring Scope

The monitoring stack is planned around:

- Prometheus
- Grafana
- Fluent Bit
- OpenSearch
- OpenSearch Dashboards
- OpenSearch Anomaly Detection

Alerts are planned to be delivered through Gmail and Telegram.

## Test Scenarios

The thesis experiments focus on:

- HTTP flood
- Endpoint scanning
- Checkout abuse

## Notes

- `adservice` and `recommendationservice` are not deployed and are not required by the frontend.
- The built-in Online Boutique `loadgenerator` is not part of the reduced application runtime.
- The Docker Compose setup is the quickest local path for application-only testing.
- Kubernetes manifests are retained for namespace-based application and monitoring deployment.
