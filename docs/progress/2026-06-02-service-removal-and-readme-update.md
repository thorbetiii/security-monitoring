# Progress Note - 2026-06-02

## Milestone

The reduced Online Boutique thesis application was successfully cleaned, containerized, deployed to local Kubernetes, and connected to the initial Prometheus/Grafana monitoring stack.

## Updated Thesis Direction

The thesis project scope was adjusted to better match the e-commerce nature of Google Online Boutique.

The original login/brute-force direction was removed from the main implementation. The main experimental scenarios are now:

* HTTP flood
* Endpoint scanning
* Checkout abuse

Login abuse, brute-force testing, Keycloak, and SQL injection are kept as possible future work.

## Runtime Architecture Decision

The project now uses two main execution stages:

1. **Docker Compose**
   Used for local container build, dependency understanding, and service-level validation.

2. **Local Kubernetes**
   Used as the main thesis deployment environment for monitoring, alerting, and attack/abuse simulation.

The Kubernetes deployment uses two namespaces:

* `application` for the reduced Online Boutique application
* `monitoring` for Prometheus, Grafana, and later OpenSearch/Fluent Bit

## Namespace

Application namespace:

* `application`

Monitoring namespace:

* `monitoring`

## Services Kept

The reduced application keeps the core e-commerce workflow services:

* `frontend`
* `productcatalogservice`
* `cartservice`
* `redis-cart`
* `checkoutservice`
* `paymentservice`
* `shippingservice`
* `currencyservice`
* `emailservice`

These services support product browsing, cart operations, and checkout flow.

## Services Removed from Main Runtime

The following services were removed from the main thesis runtime:

* `adservice`
* `recommendationservice`
* `loadgenerator`

The custom `loginservice` from the earlier idea is also excluded from the new main implementation.

## Source Code and Frontend Cleanup

The source code was updated to remove ad and recommendation dependencies from the frontend.

Completed changes include:

* Removed frontend startup dependencies on:

  * `AD_SERVICE_ADDR`
  * `RECOMMENDATION_SERVICE_ADDR`
* Removed frontend gRPC connection fields and startup connection calls for ad and recommendation services.
* Removed frontend helper logic for:

  * ad retrieval
  * product recommendations
* Removed UI integration for:

  * ads
  * recommendations
* Deleted unused frontend templates:

  * `templates/ad.html`
  * `templates/recommendations.html`
* Removed ad/recommendation blocks from product, cart, and order pages.
* Removed unused ad/recommendation CSS.
* Kept `SHOPPING_ASSISTANT_SERVICE_ADDR` with `ENABLE_ASSISTANT=false` because the current frontend startup code still requires the environment variable to exist, even though the shopping assistant feature is disabled and not deployed.

## Docker Compose Work

A root-level `docker-compose.yml` was created and updated for the reduced application.

The Compose file is used to:

* Build thesis-specific Docker images from local source code.
* Understand service dependencies.
* Validate the reduced application before Kubernetes deployment.
* Group the application containers under the thesis project.

The Docker images were tagged using the thesis tag:

* `security-monitoring/frontend:thesis`
* `security-monitoring/productcatalogservice:thesis`
* `security-monitoring/cartservice:thesis`
* `security-monitoring/checkoutservice:thesis`
* `security-monitoring/paymentservice:thesis`
* `security-monitoring/shippingservice:thesis`
* `security-monitoring/currencyservice:thesis`
* `security-monitoring/emailservice:thesis`

Redis uses the official image:

* `redis:alpine`

## Kubernetes Deployment Work

The reduced application was deployed to local Kubernetes in the `application` namespace.

All nine application pods were successfully running:

* `frontend`
* `productcatalogservice`
* `cartservice`
* `redis-cart`
* `checkoutservice`
* `paymentservice`
* `shippingservice`
* `currencyservice`
* `emailservice`

The deployment uses Kubernetes Deployments and Services, with common project labels:

```yaml
project: security-monitoring
environment: thesis
layer: application
```

These labels allow the project resources to be grouped and queried more easily.

Example:

```bash
kubectl get all -n application -l project=security-monitoring
```

## Docker Compose vs Kubernetes Note

A separate note was created to document the practical difference between Docker Compose and Kubernetes.

Main observations:

* Docker Compose exposes the frontend directly using port mapping, for example `8080:8080`.
* Kubernetes pods run inside the cluster network, so the frontend is accessed using port forwarding, NodePort, LoadBalancer, or Ingress.
* For local testing, `kubectl port-forward` is used:

```bash
kubectl port-forward svc/frontend 8080:80 -n application
```

Then the frontend can be accessed at:

```text
http://localhost:8080
```

## Monitoring Stack Progress

The initial monitoring layer was started using Helm and `kube-prometheus-stack`.

Installed components:

* Prometheus
* Grafana
* Alertmanager
* Prometheus Operator
* kube-state-metrics

Node Exporter produced a crash issue in the local Docker Desktop Kubernetes environment because of host filesystem mount compatibility. The issue was identified and Node Exporter was disabled because the thesis mainly focuses on pod/application-level monitoring rather than host-level metrics.

Prometheus and Grafana were successfully accessed locally through port forwarding:

Prometheus:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring
```

Grafana:

```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

Grafana login:

```text
Username: admin
Password: admin123
```

## Dashboard Progress

A Grafana dashboard named **Application Monitoring Overview** was started.

Working panels include:

* Running Application Pods
* Application Pod Ready Status
* Pod Restart-related metrics
* CPU Usage by Pod
* Memory Usage by Pod
* Top 5 Pods by CPU Usage
* Top 5 Pods by Memory Usage

Network panels were removed for now because the current Prometheus setup does not expose `container_network_receive_bytes_total`. This is acceptable because the initial dashboard focuses on application health, CPU, memory, and restart behavior. Network metrics can be revisited later if needed.

## Validation Performed

The following validation steps were performed:

* Verified Docker Compose configuration.
* Built Docker images with the `:thesis` tag.
* Removed old `latest` images to avoid confusion.
* Deployed the reduced application to Kubernetes.
* Confirmed all application pods were running.
* Cleaned old namespaces from the previous project.
* Installed Prometheus and Grafana using Helm.
* Verified Prometheus had access to Kubernetes application metrics.
* Created initial Grafana dashboard panels.
* Confirmed CPU and memory metrics are available for application pods.

## Result

By the end of 2026-06-02, the application foundation was successfully completed.

The project now has:

* A cleaned reduced Online Boutique application.
* A working Docker Compose setup.
* Locally built thesis-tagged Docker images.
* A successful Kubernetes deployment in the `application` namespace.
* A clean Kubernetes runtime state.
* A working Prometheus/Grafana monitoring foundation.
* An initial Grafana dashboard for application monitoring.

This completes the main application deployment phase and starts the monitoring phase.
