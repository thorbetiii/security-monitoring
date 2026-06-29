# Project Progress Report – 29 June 2026

## 1. Progress Summary

The technical implementation of the bachelor thesis project has now been completed.

The previous project stage completed the reduced Kubernetes application, metrics monitoring, structured log collection, four OpenSearch anomaly detectors, and three formal attack experiments. The final implementation stage completed persistence and end-to-end notification delivery for both monitoring paths:

- Prometheus and Grafana metrics monitoring
- Grafana rule-based alerts
- Grafana email notifications
- Grafana Telegram notifications
- Fluent Bit application-log collection
- OpenSearch log storage and anomaly detection
- Four detector-specific OpenSearch monitors
- OpenSearch Gmail notifications
- Three-minute notification validation workloads
- Final notification and persistence evidence collection

The completed system now demonstrates two complementary alert-delivery paths:

```text
Application metrics
        ↓
Prometheus
        ↓
Grafana alert rules
        ↓
Email and Telegram notifications
```

```text
Application logs
        ↓
Fluent Bit
        ↓
OpenSearch anomaly detectors
        ↓
Detector-specific alerting monitors
        ↓
Gmail notifications
```

The project implementation is now frozen. The remaining work is report writing, figure preparation, evidence selection, and final repository review.

---

## 2. Final System Scope

### 2.1 Application Environment

The target application remains the reduced Google Online Boutique deployment.

The active services are:

- `frontend`
- `productcatalogservice`
- `cartservice`
- `redis-cart`
- `checkoutservice`
- `paymentservice`
- `shippingservice`
- `currencyservice`
- `emailservice`

The following original services are not part of the deployed thesis environment:

- `adservice`
- `recommendationservice`
- `loadgenerator`

Traffic generation is handled through custom Locust workloads.

### 2.2 Kubernetes Namespaces

The project uses two namespaces:

- `application`
- `monitoring`

The `application` namespace contains the reduced Online Boutique deployment.

The `monitoring` namespace contains:

- Prometheus
- Grafana
- Alertmanager
- Fluent Bit
- OpenSearch
- OpenSearch Dashboards

### 2.3 Final Security Scenarios

The final controlled scenarios are:

1. Endpoint scanning
2. Application-layer HTTP flood
3. Checkout workflow abuse

Login brute force, Keycloak monitoring, and SQL injection remain outside the implemented scope and may be discussed as future work.

---

## 3. Persistence and Credential Handling

### 3.1 Grafana Persistence

Grafana was migrated from ephemeral storage to the persistent volume claim:

```text
grafana-storage
```

The deployment strategy was set to:

```text
Recreate
```

This avoids a `ReadWriteOnce` volume conflict during Grafana replacement or upgrade.

The persistent Grafana data preserves:

- Dashboards
- Alert rules
- Contact points
- Notification policies
- User-created configuration
- Grafana database state

Evidence and backups are stored under:

```text
evidence/06-notification-path/grafana/
```

### 3.2 OpenSearch Persistence

OpenSearch persistence remains enabled with an 8 Gi persistent volume.

The OpenSearch volume preserves:

- Application log indices
- Detector definitions
- Detector model state
- Anomaly results
- Alerting monitors
- Triggers and actions
- Notification channel configuration
- Other OpenSearch system indices

### 3.3 Notification Credentials

Notification passwords are supplied through Kubernetes Secrets rather than being embedded directly in experiment scripts.

Grafana SMTP credentials are read from:

```text
grafana-smtp-credentials
```

OpenSearch notification credentials are loaded into the OpenSearch keystore from:

```text
opensearch-notification-credentials
```

The credential values must not be committed to the public repository.

---

## 4. Grafana Notification Path

### 4.1 Rule-Based Alerting

The final Grafana rule set contains:

- Application Pod Not Ready
- Application Pod Restart Detected
- Frontend CPU Spike
- Checkout Service CPU Spike
- High CPU Usage by Pod
- High Memory Usage by Pod

These rules provide deterministic monitoring for:

- Availability
- Container stability
- CPU pressure
- Memory pressure

### 4.2 Notification Destinations

Grafana notification delivery was configured for:

- Gmail
- Telegram

Telegram is used for Grafana alerts through the Security Monitoring Alerts chat and bot integration.

OpenSearch detector alerts use Gmail only.

### 4.3 Validated Grafana Notifications

During the final validation workload, the following Grafana alerts fired:

- `Frontend CPU Spike`
- `High CPU Usage by Pod`

Both alerts were delivered successfully through:

- Telegram
- Gmail

The notification messages contained:

- Alert state
- Metric value
- Alert name
- Pod
- Namespace
- Project label
- Severity
- Description
- Source link
- Silence link

This validates the complete metrics notification path:

```text
Application workload
        ↓
Prometheus metric
        ↓
Grafana rule evaluation
        ↓
Grafana contact point
        ↓
Telegram and Gmail
```

---

## 5. OpenSearch Notification Path

### 5.1 SMTP Sender and Email Channel

The OpenSearch notification configuration uses:

```text
Sender name: thesis_gmail
Channel name: thesis-email
Transport: SMTP with STARTTLS
```

A direct channel test returned successful delivery before detector monitors were connected.

### 5.2 Detector-Specific Monitors

Four per-query monitors were created and enabled.

| Detector | Monitor | Trigger |
|---|---|---|
| AD-01 | `MON-AD01-Application-Log-Volume` | `TRG-AD01` |
| AD-02R | `MON-AD02R-Frontend-HTTP-Behaviour` | `TRG-AD02R` |
| AD-03 | `MON-AD03-Endpoint-Scanning` | `TRG-AD03-Endpoint-Scanning-Anomaly` |
| AD-04R | `MON-AD04R-Checkout-Workflow` | `TRG-AD04R` |

Each monitor queries the anomaly-result history for its exact detector ID and sends an action through the existing `thesis-email` channel when a positive anomaly result enters the search window.

### 5.3 Final Detector Mapping

| Detector | Detector ID | Features |
|---|---|---|
| `Application_Log_Volume_Anomaly_Detector` | `gBrZ054Bc5K54Bmgc9jj` | `log_count` |
| `AD_02R_Frontend_HTTP_Behaviour` | `aTnM9J4B5r61Gbzyp2UM` | `request_count`, `average_latency_ms` |
| `AD_03_Endpoint_Scanning_Behaviour` | `kDgI9J4B5r61GbzyHLG3` | `unique_path_count` |
| `AD_04R_Checkout_Workflow_Behaviour` | `WDla9J4B5r61GbzyczN7` | `checkout_count`, `unique_checkout_sessions` |

The detector interval is one minute, with a one-minute window delay and a shingle size of eight.

---

## 6. Three-Minute Notification Validation

Three short workloads were executed to validate the alert-delivery paths without repeating the full formal experiment protocol.

These runs validate notification integration. They do not replace the earlier formal baseline–attack–recovery experiments.

### 6.1 Endpoint-Scanning Validation

Workload:

```text
Locust users: 2
Duration: 3 minutes
Candidate behavior: repeated reconnaissance paths
```

Observed workload result:

| Metric | Result |
|---|---:|
| Requests | 669 |
| Failures | 0 |
| Average request rate | 3.7316 requests/s |
| Average response time | 9.72 ms |

Notification result:

- AD-03 produced a positive anomaly.
- `MON-AD03-Endpoint-Scanning` entered alert status.
- The trigger generated one OpenSearch alert.
- The Gmail notification was delivered at approximately 15:19 local time.
- No monitor error was shown.

### 6.2 Checkout-Abuse Validation

Workload:

```text
Locust users: 5
Duration: 3 minutes
Behavior: repeated valid cart and checkout workflow
```

Observed workload result:

| Metric | Result |
|---|---:|
| Total requests | 881 |
| Checkout POST requests | 219 |
| Failures | 0 |
| Average request rate | 4.9380 requests/s |
| Average response time | 21.78 ms |

Notification result:

- AD-04R produced a positive anomaly.
- `MON-AD04R-Checkout-Workflow` entered alert status.
- The trigger generated one OpenSearch alert.
- The Gmail notification was delivered at approximately 15:24 local time.
- No monitor error was shown.

### 6.3 HTTP-Flood Validation

Workload:

```text
Locust users: 20
Duration: 3 minutes
Behavior: high-rate requests to valid application paths
```

Observed workload result:

| Metric | Result |
|---|---:|
| Requests | 3,530 |
| Failures | 0 |
| Average request rate | 19.8182 requests/s |
| Average response time | 23.80 ms |

Notification result:

- AD-01 produced a positive anomaly.
- AD-02R produced a positive anomaly during this short validation run.
- `MON-AD01-Application-Log-Volume` generated an email at approximately 15:21 local time.
- `MON-AD02R-Frontend-HTTP-Behaviour` generated an email at approximately 15:20 local time.
- The OpenSearch alerting page showed one generated alert for each monitor.
- No monitor error was shown.

Grafana also detected CPU pressure during this workload and delivered its CPU alerts through Gmail and Telegram.

---

## 7. OpenSearch Validation Result

The OpenSearch live-anomaly dashboard displayed positive results from all four detectors during the final validation sequence.

Observed latest anomaly grades included:

- AD-01: `1.00`
- AD-03: `1.00`
- AD-04R: `1.00`
- AD-02R: approximately `0.25`

The Alerting page showed one generated alert for each trigger:

```text
TRG-AD01
TRG-AD02R
TRG-AD03-Endpoint-Scanning-Anomaly
TRG-AD04R
```

The alert table showed:

```text
Errors: 0
```

The Gmail inbox contained detector-generated messages for:

- Application log-volume anomaly
- Frontend HTTP behavior anomaly
- Endpoint-scanning anomaly
- Checkout workflow anomaly

This confirms that the messages were produced by actual detector monitors rather than only by a manual notification-channel test.

---

## 8. Interpretation of the AD-02R Validation

AD-02R did not detect any of the three formal HTTP-flood runs completed earlier, but it produced a positive anomaly during the final three-minute notification-validation run.

This does not invalidate the formal result.

The formal experiment result remains:

```text
AD-02R formal HTTP-flood detection: 0/3
```

The final short run demonstrates only that:

- AD-02R can still produce a positive result under a later workload.
- Its monitor query is connected correctly.
- Its trigger executes correctly.
- Its email action delivers correctly.

The thesis report must keep the formal detector-performance evaluation separate from the notification-path validation.

---

## 9. Duplicate AD-01 Notification

A later AD-01 message was also delivered after the initial AD-01 email.

This is not treated as a delivery failure. It indicates that a later positive anomaly result was evaluated by the monitor and caused another notification event.

For the thesis, one successful message per monitor is sufficient to demonstrate end-to-end delivery. Repeated alerts may be discussed as a notification-noise consideration and can be controlled in future work through throttling, deduplication, or stricter trigger logic.

---

## 10. Final End-to-End Validation

### 10.1 Metrics Path

```text
Application traffic
        ↓
Kubernetes container metrics
        ↓
Prometheus
        ↓
Grafana rule evaluation
        ↓
Gmail and Telegram
```

Validated:

- Metric collection
- Rule evaluation
- Firing alert state
- Contact-point routing
- Gmail delivery
- Telegram delivery

### 10.2 Log and Anomaly Path

```text
Application traffic
        ↓
Structured frontend logs
        ↓
Fluent Bit
        ↓
OpenSearch application-logs indices
        ↓
Random Cut Forest anomaly detector
        ↓
Detector-specific monitor
        ↓
Trigger and notification action
        ↓
Gmail
```

Validated:

- Log collection
- Structured feature availability
- Detector execution
- Positive anomaly result
- Monitor query
- Trigger execution
- Email action
- Gmail delivery

---

## 11. Evidence Organization

The final evidence structure includes:

```text
evidence/
├── 00-system-state-20260617-0859/
├── 01-baseline/
├── 01-opensearch-persistence-test/
├── 02-formal-baseline/
├── 03-endpoint-scanning/
├── 04-http-flood/
├── 05-checkout-abuse/
├── 06-notification-path/
│   ├── 3-minute-tests/
│   ├── grafana/
│   └── opensearch/
└── configuration-backups/
```

The three-minute test directory contains:

- Locust CSV statistics
- Locust statistics history
- Failure and exception exports
- HTML reports

The final notification screenshots should be retained under the corresponding Grafana and OpenSearch evidence directories.

Important screenshots include:

- Four enabled OpenSearch monitors
- OpenSearch live anomalies for all four detectors
- OpenSearch alert table with four generated alerts
- Four detector-generated Gmail messages
- Grafana Telegram messages
- Grafana Gmail messages

---

## 12. Completed Technical Work

The following implementation tasks are complete:

- Reduced Online Boutique application
- Docker Compose application validation
- Kubernetes deployment
- Two-namespace organization
- Prometheus metric collection
- Grafana dashboards
- Six Grafana alert rules
- Grafana persistent storage
- Grafana Gmail delivery
- Grafana Telegram delivery
- Fluent Bit application-log collection
- OpenSearch log storage
- OpenSearch persistent storage
- OpenSearch Dashboards
- Four OpenSearch anomaly detectors
- Endpoint-scanning pilot and three formal runs
- HTTP-flood pilot and three formal runs
- Checkout-abuse pilot and three formal runs
- Recovery-period evaluation
- Cross-detector evaluation
- OpenSearch SMTP sender
- OpenSearch email notification channel
- Four detector-specific OpenSearch monitors
- Four detector-specific triggers
- Detector-generated Gmail delivery
- Three-minute notification validation
- Notification evidence collection
- Configuration and persistence backups

---

## 13. Remaining Work

The technical system should now remain frozen.

The remaining work is documentation:

- Replace the outdated repository README.
- Integrate the implementation into the thesis report.
- Finalize the architecture diagram.
- Explain the metrics and log data flows.
- Document detector features and monitor logic.
- Add formal experiment tables.
- Add notification-path validation evidence.
- Compare Grafana rule-based detection with OpenSearch anomaly detection.
- Discuss detector misses and online-model adaptation.
- Document limitations and future work.
- Review the repository for exposed credentials or unnecessary runtime artifacts.
- Perform final formatting, proofreading, and submission preparation.

---

## 14. Main Project Findings

The completed implementation supports the following conclusions:

1. Metrics-based monitoring detected visible infrastructure pressure consistently during the HTTP-flood experiments.
2. Path-diversity anomaly detection identified endpoint scanning without corresponding resource alerts.
3. Checkout-workflow anomaly detection identified business-process abuse without corresponding CPU, memory, readiness, or restart alerts.
4. No single detector was sufficient for every abnormal behavior.
5. Rule-based Grafana alerts and OpenSearch anomaly detection provided complementary coverage.
6. Both monitoring paths can now deliver actionable notifications to external channels.
7. The system remained available during all formal scenarios, with no formal Locust request failures.
8. Detector misses were preserved honestly rather than hidden through repeated reruns.
9. Notification validation must be interpreted separately from formal detector-performance evaluation.

The main implementation conclusion is:

> Metrics-based monitoring is effective for visible infrastructure pressure, while log-based anomaly detection can identify application behavior that remains below conventional resource thresholds. Connecting both layers to external notification channels creates a more complete security-monitoring workflow.

---

## 15. Final Project Status

```text
Application implementation                  Complete
Kubernetes deployment                       Complete
Metrics monitoring                          Complete
Log collection and storage                  Complete
Grafana dashboards and rules                Complete
OpenSearch anomaly detectors                Complete
Formal attack experiments                   Complete
Baseline and recovery evaluation            Complete
Grafana Gmail notifications                 Complete
Grafana Telegram notifications              Complete
OpenSearch detector monitors                Complete
OpenSearch Gmail notifications              Complete
Persistence and configuration backups       Complete
Technical project implementation            Complete
README update                               In progress
Thesis report                               Remaining
```

The project is now ready to move from implementation to final report writing.
