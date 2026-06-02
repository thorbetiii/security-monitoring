# Docker Compose vs Kubernetes Notes

Date: 2026-06-02  
Project: Security Monitoring for Microservice Environments

## Purpose

This note records the practical differences observed while running the reduced Online Boutique thesis application using Docker Compose and Kubernetes.

The reduced application contains:

- frontend
- productcatalogservice
- cartservice
- redis-cart
- checkoutservice
- paymentservice
- shippingservice
- currencyservice
- emailservice

The application is first tested with Docker Compose, then deployed to local Kubernetes in the `application` namespace.

---

## 1. Main Difference

Docker Compose runs containers directly on Docker Desktop.

Kubernetes runs application containers as Pods inside a Kubernetes cluster. The containers are still visible in Docker Desktop, but they are managed by Kubernetes, not by Docker Compose.

This means that Kubernetes containers should be controlled using `kubectl`, not `docker stop`, `docker rm`, or Docker Desktop manual container actions.

---

## 2. Accessing the Frontend

### Docker Compose

In Docker Compose, the frontend can be exposed directly using the `ports` field:

```yaml
ports:
  - "8080:8080"
```

After starting the system:

```bash
docker compose up -d --build
```

The webpage can be accessed directly from the host machine:

```text
http://localhost:8080
```

### Kubernetes

In Kubernetes, the frontend Pod runs inside the cluster network. A `ClusterIP` service is only reachable inside the cluster.

To access the frontend from the host machine, use port forwarding:

```bash
kubectl port-forward svc/frontend 8080:80 -n application
```

Then open:

```text
http://localhost:8080
```

Alternative Kubernetes exposure methods include:

- `NodePort`
- `LoadBalancer`
- Ingress

For this thesis project, `kubectl port-forward` is acceptable for local testing and evidence collection because it is simple and controlled.

---

## 3. Service Discovery

### Docker Compose

Services communicate using Docker Compose service names on the Compose network.

Example:

```yaml
PRODUCT_CATALOG_SERVICE_ADDR: productcatalogservice:3550
CART_SERVICE_ADDR: cartservice:7070
```

Docker Compose automatically creates a network where service names resolve to containers.

### Kubernetes

Services communicate using Kubernetes Service names inside the namespace.

Example:

```yaml
- name: PRODUCT_CATALOG_SERVICE_ADDR
  value: "productcatalogservice:3550"
- name: CART_SERVICE_ADDR
  value: "cartservice:7070"
```

Because all application services are deployed in the same namespace, short service names such as `cartservice` and `checkoutservice` are enough.

---

## 4. Container Management

### Docker Compose

Common commands:

```bash
docker compose up -d --build
docker compose ps
docker compose logs frontend
docker compose down
```

Docker Compose manages the application as a local container group.

### Kubernetes

Common commands:

```bash
kubectl get pods -n application
kubectl get svc -n application
kubectl logs deployment/frontend -n application
kubectl delete -f application/manifests/application-reduced.yaml
kubectl apply -f application/manifests/application-reduced.yaml
```

Kubernetes manages the application using Deployments, Pods, and Services.

---

## 5. Image Usage

### Docker Compose

Docker Compose can build images directly from the local source code:

```yaml
frontend:
  image: security-monitoring/frontend:thesis
  build:
    context: ./src/frontend
```

Running:

```bash
docker compose build
```

creates local Docker images with thesis-specific tags.

### Kubernetes

Kubernetes deploys images declared in the manifest:

```yaml
image: security-monitoring/frontend:thesis
imagePullPolicy: IfNotPresent
```

When using local Kubernetes, image availability depends on the Kubernetes runtime. If the cluster cannot see local Docker images, image pull errors such as `ImagePullBackOff` or `ErrImageNeverPull` may occur.

In this project, the issue was resolved by switching to the correct Kubernetes environment/runtime so that the locally built thesis images were available to the cluster.

---

## 6. Namespaces and Isolation

Docker Compose groups services using a Compose project name and Docker network.

Kubernetes groups resources using namespaces and labels.

This project uses:

```text
application
monitoring
```

The application services are deployed in:

```text
namespace: application
```

The monitoring stack will be deployed in:

```text
namespace: monitoring
```

Common labels are used to group resources:

```yaml
project: security-monitoring
environment: thesis
layer: application
```

Useful command:

```bash
kubectl get all -n application -l project=security-monitoring
```

---

## 7. Observed Kubernetes Deployment Result

The reduced application was successfully deployed in the `application` namespace.

Running pods:

```text
cartservice
checkoutservice
currencyservice
emailservice
frontend
paymentservice
productcatalogservice
redis-cart
shippingservice
```

The `kube-system` namespace contains Kubernetes system components such as CoreDNS, API server, scheduler, controller manager, and kube-proxy. These are expected and should not be deleted.

---

## 8. Practical Summary

Docker Compose is useful for:

- understanding service dependencies
- building service images from source code
- quickly testing the application locally
- validating container-level configuration

Kubernetes is useful for:

- deploying the application in a cluster-like environment
- using namespaces, Deployments, Pods, and Services
- preparing realistic monitoring with Prometheus, Grafana, Fluent Bit, and OpenSearch
- supporting the thesis experiments and detection workflow

In this thesis project, Docker Compose is used as the container build and local validation stage, while Kubernetes is used as the main experimental deployment environment.

---

## 9. Report-Friendly Explanation

The project uses both Docker Compose and Kubernetes for different purposes. Docker Compose is used to build and validate the reduced microservice application locally because it provides a simple way to understand service dependencies and test container startup. Kubernetes is used as the main deployment environment because the thesis focuses on monitoring and detecting abnormal behavior in a microservice system deployed in a cluster. Unlike Docker Compose, Kubernetes requires Services, Deployments, and namespace management, and application access is commonly performed through port forwarding, NodePort, LoadBalancer, or Ingress. In this local setup, port forwarding is used to access the frontend during testing.
