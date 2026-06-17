# Project Progress Report – 17 June 2026

## 1. Progress Summary

The monitoring environment and the first formal experiment stage have now been completed successfully. The reduced Online Boutique application is running on the local Kubernetes cluster, application metrics are collected through Prometheus and visualized in Grafana, application logs are collected by Fluent Bit and stored in OpenSearch, and the OpenSearch Anomaly Detection plugin is running with a log-volume detector.

The main achievement of this stage was the completion of the formal normal-traffic baseline. This baseline will be used as the reference for comparison with the upcoming attack scenarios.

## 2. Completed Work

### 2.1 Kubernetes Application Environment

The reduced Online Boutique application remains deployed in the `application` namespace with nine running services:

- frontend
- productcatalogservice
- cartservice
- redis-cart
- checkoutservice
- paymentservice
- shippingservice
- currencyservice
- emailservice

During the formal baseline, all nine application Pods remained running and ready, and no Pod restart occurred within the selected test period.

### 2.2 Metrics Monitoring

Prometheus and Grafana are operational in the `monitoring` namespace.

The Grafana dashboard named **Application Monitoring Overview** displays:

- Running application Pods
- Pod readiness status
- Pod restarts within the selected time range
- CPU usage by Pod
- Memory usage by Pod

The following Grafana alert rules are configured and evaluated every 30 seconds:

- Application Pod Not Ready
- Application Pod Restart Detected
- Frontend CPU Spike
- Checkout Service CPU Spike
- High CPU Usage by Pod
- High Memory Usage by Pod

All alert rules remained in the normal state during the formal baseline.

### 2.3 Log Collection Pipeline

The log pipeline is operating correctly:

```text
Application containers
        ↓
Container stdout/stderr log files
        ↓
Fluent Bit
        ↓
Kubernetes metadata enrichment
        ↓
OpenSearch
        ↓
OpenSearch Dashboards
```

Fluent Bit successfully monitors the log files of all nine application Pods. Logs are stored in indices matching:

```text
application-logs-*
```

The `application-logs-*` index template uses one primary shard and zero replicas, which is suitable for the single-node OpenSearch deployment.

### 2.4 OpenSearch Persistence

OpenSearch persistence was enabled using an 8 GiB Kubernetes PersistentVolumeClaim.

The active claim is:

```text
opensearch-cluster-single-opensearch-cluster-single-0
```

The volume is mounted at:

```text
/usr/share/opensearch/data
```

Persistence was verified by deleting and recreating the OpenSearch Pod. After the Pod restarted:

- The application log index remained available.
- The stored document count remained unchanged.
- The anomaly detector configuration remained available.
- The PersistentVolumeClaim remained bound.

This confirms that OpenSearch data and detector configurations survive Pod recreation.

### 2.5 Anomaly Detector

The following OpenSearch anomaly detector is active:

```text
Name: Application_Log_Volume_Anomaly_Detector
Index pattern: application-logs-*
Time field: @timestamp
Feature: log_count
Detector interval: 1 minute
```

The detector analyzes log volume using the OpenSearch Random Cut Forest anomaly detection method.

During testing, the detector correctly reacted to sudden changes in traffic volume. It detected a temporary anomaly when the formal Locust workload started because the system changed from a low-traffic or idle state to continuous traffic.

This initial event is treated as a traffic-transition anomaly rather than evidence of malicious behavior.

## 3. Locust Validation

### 3.1 Smoke Test

A 30-second Locust smoke test was completed before the formal baseline.

Results:

- Total requests: 9
- Failed requests: 0
- Tested routes:
  - `/`
  - `/cart`
  - `/product/[product_id]`

The smoke test confirmed that the Locust script, frontend port-forward, and application routes worked correctly.

### 3.2 Formal Normal-Traffic Baseline

The formal baseline used the following configuration:

```text
Virtual users: 3
Spawn rate: 1 user per second
Duration: 45 minutes
Host: http://localhost:8080
Wait time: 2–5 seconds
```

Locust simulated normal shopping behavior with the following approximate task distribution:

- Homepage browsing: 45.5%
- Product viewing: 36.4%
- Cart viewing: 18.2%

Formal results:

| Metric | Result |
|---|---:|
| Total requests | 2,292 |
| Failed requests | 0 |
| Failure rate | 0% |
| Average response time | 14.64 ms |
| 95th percentile response time | 28 ms |
| Average throughput | 0.85 requests/second |

Request totals by route:

| Route | Requests | Failures |
|---|---:|---:|
| `/` | 1,033 | 0 |
| `/cart` | 418 | 0 |
| `/product/[product_id]` | 841 | 0 |

## 4. Baseline Observations

The baseline produced stable and repeatable normal behavior:

- All nine application Pods remained running.
- All application Pods remained ready.
- No Pod restarted during the selected baseline period.
- CPU usage increased after the workload started but remained low and stable.
- Memory usage remained stable.
- No Grafana alert rule entered the firing state.
- Fluent Bit continued forwarding logs without interruption.
- OpenSearch received logs continuously.
- Locust recorded no request failures.

The OpenSearch detector produced an anomaly when the workload first started. This occurred because log volume changed abruptly from idle traffic to continuous normal traffic.

For evaluation purposes, the first five minutes should be treated as a warm-up period:

```text
Warm-up period: approximately 14:15–14:20
Steady baseline period: approximately 14:20–15:00
```

After the warm-up transition, the workload and log volume remained broadly stable.

## 5. Evidence Collected

Evidence is stored under:

```text
evidence/02-formal-baseline/
```

The collected evidence includes:

- Locust CSV results
- Locust HTML report
- Application Pod state before and after the test
- Monitoring Pod state before and after the test
- OpenSearch health output
- OpenSearch index information
- OpenSearch document counts
- Grafana dashboard screenshots
- Grafana alert-rule screenshot
- OpenSearch Discover screenshot
- OpenSearch anomaly-detector screenshots

Recommended screenshot names:

```text
01-locust-request-statistics.png
02-locust-task-ratio.png
03-grafana-baseline-dashboard.png
04-grafana-alert-rules-normal.png
05-opensearch-baseline-logs.png
06-opensearch-baseline-transition-anomaly.png
```

## 6. Known Issue

The Prometheus Node Exporter Pod may still appear in `CrashLoopBackOff` on Docker Desktop because of host filesystem mount limitations.

This issue does not block the current experiments because the project uses Kubernetes Pod and container metrics rather than host-level Node Exporter metrics. The component should be disabled permanently in the Helm values file to keep the monitoring namespace clean.

## 7. Current Project Status

Completed:

- Reduced microservice application
- Docker Compose validation
- Kubernetes deployment
- Prometheus metric collection
- Grafana dashboard
- Grafana alert rules
- Fluent Bit log collection
- OpenSearch log storage
- OpenSearch Dashboards data view
- OpenSearch PersistentVolume
- Persistence recovery test
- OpenSearch anomaly detector
- Locust installation and validation
- Formal normal-traffic baseline

Pending:

- HTTP flood experiment
- Endpoint scanning experiment
- Checkout abuse experiment
- Recovery-period observations
- Comparison of baseline and attack results
- Final experiment tables and figures
- Completion of the implementation and evaluation chapters

## 8. Next Work

The next experiment is the controlled HTTP flood scenario.

The planned sequence is:

1. Start the normal three-user Locust workload.
2. Allow a ten-minute warm-up period.
3. Start the HTTP flood while normal traffic continues.
4. Run the attack for a controlled duration.
5. Stop the attack.
6. Continue normal traffic for ten minutes to observe recovery.
7. Collect Locust, Grafana, OpenSearch, anomaly-detector, and terminal evidence.
8. Compare baseline, attack, and recovery periods.

The intended experiment structure is:

```text
Normal background traffic
        ↓
HTTP flood period
        ↓
Recovery period
```

This design allows the monitoring system to distinguish the attack from the initial traffic-start transition and provides a clearer comparison with the completed formal baseline.
