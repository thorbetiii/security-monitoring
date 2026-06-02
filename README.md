# Security Monitoring for Microservice Environments

This repository contains the implementation environment for the bachelor thesis project:

**Enhancing Security Monitoring in Microservice Environments Using AI-Driven Operations**

The project uses a reduced version of Google Online Boutique as the target microservice application. The application is deployed locally on Kubernetes and monitored using a separate monitoring stack.

## Current System Scope

The system uses two Kubernetes namespaces:

- `application`: reduced Online Boutique application services
- `monitoring`: observability, logging, and detection components

## Application Services

The reduced application currently includes:

- frontend
- productcatalogservice
- cartservice
- redis-cart
- checkoutservice
- paymentservice
- shippingservice
- currencyservice
- emailservice

The following original demo services were removed from the main thesis implementation:

- adservice
- recommendationservice
- loadgenerator

Traffic generation will be handled separately using custom scripts and possibly Locust.

## Planned Monitoring Stack

The monitoring namespace will contain:

- Prometheus
- Grafana
- Fluent Bit
- OpenSearch
- OpenSearch Dashboards
- OpenSearch Anomaly Detection

## Planned Test Scenarios

The thesis experiments will focus on:

- HTTP flood
- Endpoint scanning
- Checkout abuse

Alerts are planned to be sent through:

- Gmail
- Telegram

## Deployment

Create namespaces:

```bash
kubectl apply -f application/manifests/namespaces.yaml