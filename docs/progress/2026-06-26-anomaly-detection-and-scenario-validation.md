# Project Progress Report – 26 June 2026

## 1. Progress Summary

The implementation and formal experiment phase of the bachelor thesis project has now been completed.

During this stage, the monitoring pipeline was corrected and stabilized, structured application logs were made usable in OpenSearch, four anomaly detectors were created and validated, three controlled attack scenarios were implemented with Locust, and three formal runs were completed for each scenario.

The current system combines:

- Kubernetes-based microservice deployment
- Prometheus and Grafana metrics monitoring
- Grafana rule-based alerting
- Fluent Bit log collection and parsing
- OpenSearch log storage and analysis
- OpenSearch Random Cut Forest anomaly detection
- Controlled Locust-based security experiments
- Structured evidence collection for baseline, attack, and recovery phases

The three completed formal scenarios are:

1. Endpoint scanning
2. HTTP flood
3. Checkout workflow abuse

The experiment results demonstrate that infrastructure metrics and application-log anomaly detection provide different but complementary views of abnormal behavior.

---

## 2. Final Project Scope

### 2.1 Application Environment

The target application is a reduced version of Google Online Boutique.

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

The following original Online Boutique services were removed from the main thesis implementation:

- `adservice`
- `recommendationservice`
- `loadgenerator`

Traffic generation is performed through custom Locust scripts so that normal and attack workloads can be controlled independently.

### 2.2 Kubernetes Namespaces

The project uses two main namespaces:

- `application`
- `monitoring`

The `application` namespace contains the reduced Online Boutique deployment.

The `monitoring` namespace contains:

- Prometheus
- Grafana
- Fluent Bit
- OpenSearch
- OpenSearch Dashboards

### 2.3 Final Experiment Scenarios

The final thesis experiments are:

- Endpoint scanning
- Controlled application-layer HTTP flood
- Checkout workflow abuse

Login brute force, Keycloak integration, and SQL injection were removed from the main implementation scope and may be discussed as future work.

---

## 3. Monitoring and Logging Fixes

### 3.1 Fluent Bit Log Parsing Problem

The frontend application already produced structured JSON logs, but the original Fluent Bit pipeline did not expose the HTTP fields correctly at the top level in OpenSearch.

The original records contained the application JSON inside the container log field. As a result, fields required by anomaly detectors were not directly available for aggregation.

Examples of the required fields were:

- `message`
- `http_req_path`
- `http_req_method`
- `http_resp_status`
- `http_resp_took_ms`
- `session`

### 3.2 Fluent Bit Parser Correction

The Fluent Bit configuration was updated to process the container log in two stages:

1. Parse the Kubernetes container log format.
2. Parse the application JSON stored in the `log` field.

The corrected pipeline used:

- Docker/container log parsing at the input stage
- Kubernetes metadata enrichment
- A custom `application_json` parser
- A parser filter using `Key_Name log`

The relevant logical flow is:

```text
Application JSON log
        ↓
Container stdout log
        ↓
Fluent Bit container parser
        ↓
Kubernetes metadata filter
        ↓
application_json parser
        ↓
Top-level structured OpenSearch fields
```

The Fluent Bit Helm release was upgraded and the DaemonSet rollout completed successfully.

### 3.3 Structured Log Validation

After the parser fix, OpenSearch records contained usable top-level HTTP fields together with Kubernetes metadata.

The standard completed-request filter became:

```text
kubernetes.container_name.keyword = frontend
message.keyword = request complete
```

Exact path and method filters use keyword fields, for example:

```text
http_req_path.keyword = /cart/checkout
http_req_method.keyword = POST
```

The log indices use the pattern:

```text
application-logs-*
```

This correction made it possible to build reliable feature aggregations for request count, latency, path diversity, checkout count, and session count.

---

## 4. Metrics Monitoring and Grafana Alerting

### 4.1 Grafana Dashboards

The Grafana monitoring environment was cleaned and focused on application and monitoring health.

The active application dashboard includes:

- Pod readiness
- Pod restart count
- CPU usage by Pod
- Memory usage by Pod

The unnecessary network dashboard was removed.

### 4.2 Grafana Alert Rules

The following rules were created and validated:

- Application Pod Not Ready
- Application Pod Restart Detected
- Frontend CPU Spike
- Checkout Service CPU Spike
- High CPU Usage by Pod
- High Memory Usage by Pod

Important threshold interpretation:

- CPU queries use `rate(container_cpu_usage_seconds_total[5m])`.
- A threshold of `0.05` means 0.05 CPU cores, not 5 percent.
- The high-memory threshold is `150,000,000` bytes, approximately 143 MiB.

Grafana was used as the rule-based infrastructure detection layer during all formal experiments.

---

## 5. OpenSearch Anomaly Detector Development

### 5.1 Detector Stabilization Issues

Several OpenSearch Anomaly Detection problems were encountered during development:

- Detectors remained in `INIT` for extended periods.
- The OpenSearch Dashboards UI sometimes displayed a blank detector page.
- The API showed detectors as running even when the UI did not update correctly.
- Some detectors produced `average()` aggregation errors.
- Detector creation without active matching traffic caused initialization problems.

The reliable recovery method was to recreate affected detectors while matching Locust traffic was active.

The final detectors were frozen after they reached:

```text
state: RUNNING
error: ""
init_progress: 100%
model_count: 1
```

No detector was modified during the formal three-run experiments.

### 5.2 Final Detector Set

#### AD-01 – Application Log Volume

```text
Name: Application_Log_Volume_Anomaly_Detector
ID: gBrZ054Bc5K54Bmgc9jj
Feature: log_count
```

Purpose:

- Detect large changes in total application-log volume.
- Primary detector for generic high-volume traffic.

#### AD-02R – Frontend HTTP Behavior

```text
Name: AD_02R_Frontend_HTTP_Behaviour
ID: aTnM9J4B5r61Gbzyp2UM
Features:
- request_count
- average_latency_ms
```

Purpose:

- Analyze the combined behavior of frontend request volume and response latency.

#### AD-03 – Endpoint Scanning Behavior

```text
Name: AD_03_Endpoint_Scanning_Behaviour
ID: kDgI9J4B5r61GbzyHLG3
Feature: unique_path_count
```

Purpose:

- Detect reconnaissance behavior through rapid growth in the number of distinct requested paths.

#### AD-04R – Checkout Workflow Behavior

```text
Name: AD_04R_Checkout_Workflow_Behaviour
ID: WDla9J4B5r61GbzyczN7
Features:
- checkout_count
- unique_checkout_sessions
```

Purpose:

- Detect abnormal use of the valid checkout workflow.
- Distinguish business-operation abuse from generic infrastructure pressure.

---

## 6. Experiment Design

### 6.1 General Experiment Structure

The experiments were designed around three measured phases:

```text
Normal baseline
        ↓
Attack
        ↓
Recovery
```

The standard formal structure was:

- 10 minutes measured normal behavior
- 5 minutes attack behavior
- 10 minutes recovery behavior

The checkout-abuse experiment additionally used a 10-minute preconditioning period before the measured baseline.

### 6.2 Evidence Rules

Each formal scenario used three valid runs.

A run was included only when:

- The complete experiment protocol executed.
- Locust completed successfully.
- Formal timestamps were recorded.
- Baseline, attack, and recovery evidence was available.
- Pod state and restart state were captured.
- OpenSearch detector results were queryable.

Failed orchestration attempts were archived separately and excluded from formal calculations.

A formal run was not repeated merely because a detector did not fire. Valid detector misses were preserved as experimental results.

---

## 7. Scenario 1 – Endpoint Scanning

### 7.1 Scenario Implementation

The endpoint-scanning script is:

```text
experiments/attacks/endpoint-scan-locustfile.py
```

Configuration:

- 63 candidate paths
- 2 Locust users
- Approximately 3.7 requests/second
- 10-minute normal phase
- 5-minute scan phase
- 10-minute recovery phase

The scenario created reconnaissance-like traffic by requesting many distinct paths while keeping the overall request rate moderate.

### 7.2 Formal Results

| Metric | Run 01 | Run 02 | Run 03 |
|---|---:|---:|---:|
| Requests | 1,119 | 1,117 | 1,109 |
| Failures | 0 | 0 | 0 |
| Request rate | 3.7387/s | 3.7352/s | 3.7081/s |
| Average response time | 7.33 ms | 7.35 ms | 7.42 ms |
| AD-03 detected | Yes | Yes | Yes |
| Anomaly grade | 1.0 | 1.0 | 1.0 |
| Confidence | ~0.9924 | ~0.9933 | ~0.9935 |
| Detection latency | ~74.6 s | ~73.6 s | ~120.1 s |

Aggregate results:

- Formal detections: 3/3
- Detection rate: 100%
- Total requests: 3,345
- Total failures: 0
- Average confidence: approximately 0.9931
- Average detection latency: approximately 89.4 seconds
- Grafana resource alerts: 0
- New Pod restarts: 0
- Application availability: maintained

### 7.3 Endpoint-Scanning Conclusion

AD-03 detected path-diversity changes that were not visible as CPU, memory, restart, or readiness incidents.

This scenario demonstrated that log-based behavioral detection can identify reconnaissance activity even when infrastructure resource usage remains normal.

Evidence is stored under:

```text
evidence/03-endpoint-scanning/
```

---

## 8. Scenario 2 – HTTP Flood

### 8.1 Scenario Implementation

The HTTP-flood script is:

```text
experiments/attacks/http-flood-locustfile.py
```

The scenario used only valid application paths:

- `/`
- `/product/OLJCESPC7Z`
- `/cart`

Final attack configuration:

- 20 Locust users
- Spawn rate: 5 users/second
- Constant throughput behavior
- Approximately 20 requests/second
- 10-minute normal phase
- 5-minute flood phase
- 10-minute recovery phase

The fixed paths ensured that the HTTP flood tested request volume rather than path diversity.

### 8.2 Infrastructure Behavior

The flood caused visible resource pressure.

Across the formal runs:

- Frontend CPU Spike fired in 3/3 runs.
- High CPU Usage by Pod fired for `currencyservice` in 3/3 runs.
- High Memory Usage by Pod fired for `currencyservice` in 3/3 runs.
- Application Pod Not Ready remained quiet.
- Application Pod Restart Detected remained quiet.
- No request failed.
- All application Pods remained available.

The `currencyservice` working-set memory remained elevated after the attack period. This is described as persistent elevated working-set memory; it was not confirmed as a memory leak.

### 8.3 Anomaly Detector Results

Formal detector performance:

- AD-01 detected 2/3 formal runs.
- AD-02R detected 0/3 formal runs.
- AD-03 correctly remained quiet because path diversity was fixed.
- AD-02R had produced a positive anomaly during the pilot but not during the formal runs.

The formal AD-01 detection rate was:

```text
2/3 = 66.7%
```

The Run 03 all-result queries showed that both AD-01 and AD-02R processed the flood intervals but assigned anomaly grade zero. These were genuine detector misses rather than missing data.

### 8.4 Formal Workload Summary

Across the three formal runs:

- Total requests: 17,790
- Total failures: 0
- Average request rate: approximately 19.89 requests/second
- Average client response time: approximately 21.09 ms
- Flood traffic: approximately 1,234 requests/minute
- Fixed application paths: 3
- HTTP responses: successful

Average Grafana firing latencies:

- Frontend CPU Spike: approximately 224.5 seconds
- High CPU Usage by Pod: approximately 285.5 seconds
- High Memory Usage by Pod: approximately 199.5 seconds

### 8.5 HTTP-Flood Conclusion

The HTTP-flood scenario showed that metrics-based alerting was highly effective for visible infrastructure pressure.

The anomaly-detection results were less consistent:

- AD-01 detected two runs.
- AD-02R did not detect the formal runs.
- Grafana detected CPU and memory symptoms consistently.

A possible explanation is adaptation by the online Random Cut Forest model after repeated similar traffic. Stable or decreasing latency may also have reduced the sensitivity of AD-02R. These are plausible interpretations rather than separately proven causes.

Evidence is stored under:

```text
evidence/04-http-flood/
```

---

## 9. Scenario 3 – Checkout Workflow Abuse

### 9.1 Scenario Preparation

The application checkout route and required form values were verified from the frontend source code.

The validated workflow was:

```text
GET /product/OLJCESPC7Z
POST /cart
GET /cart
POST /cart/checkout
```

The checkout request used valid customer, address, and payment-form data.

Manual testing confirmed:

- Persistent session tracking
- Successful add-to-cart redirect
- Successful checkout response
- `checkout_count` aggregation
- `unique_checkout_sessions` aggregation
- No missing session value

### 9.2 Locust Scripts

Normal checkout workload:

```text
experiments/baseline/checkout-normal-locustfile.py
```

Checkout-abuse workload:

```text
experiments/attacks/checkout-abuse-locustfile.py
```

Formal orchestration:

```text
experiments/run-checkout-formal.ps1
```

Normal workload:

- 2 persistent users
- Wait time: 60–90 seconds
- Continuous normal traffic

Attack workload:

- 5 persistent users
- Spawn rate: 1 user/second
- Wait time: 3–5 seconds
- Repeated valid checkout workflow
- Duration: 5 minutes

### 9.3 Continuous-Baseline Protocol

The pilot used separate normal, attack, and recovery processes. This created empty transition intervals.

The formal protocol was improved so the two normal users remained active across the entire experiment:

- 10 minutes preconditioning
- 10 minutes measured baseline
- 5 minutes normal traffic plus checkout abuse
- 10 minutes normal recovery

This removed artificial zero-traffic gaps and produced a cleaner behavioral transition.

### 9.4 Formal Runner Fixes

Several Windows PowerShell orchestration problems were found and corrected:

1. Relative paths failed inside `Start-Job`.
2. `Start-Job` was replaced with `Start-Process`.
3. Locust writes normal information logs to stderr, which caused `NativeCommandError` when piped through PowerShell.
4. Attack output was redirected directly to evidence files.
5. Windows PowerShell sometimes returned a blank process exit code after Locust finished.
6. The runner was updated to refresh the process object and fall back to parsing Locust's final `Shutting down (exit code 0)` message.
7. Invalid attempts were archived with explanatory notes and excluded from formal results.

The final runner automatically records:

- Pod state before and after
- Restart counts before and after
- Preconditioning start
- Experiment start
- Attack start
- Attack end
- Recovery end
- ISO timestamps
- Epoch timestamps
- Locust CSV results
- Locust HTML reports
- Console output and errors
- Run completion status

### 9.5 Formal Results

| Metric | Run 01 | Run 02 | Run 03 |
|---|---:|---:|---:|
| Baseline checkout rate | 1.50/min | 1.60/min | 1.60/min |
| Attack checkout rate | 74.65/min | 75.04/min | 74.42/min |
| Increase over baseline | 49.77x | 46.91x | 46.52x |
| Recovery checkout rate | 1.60/min | 1.80/min | 1.70/min |
| AD-04R grade | 1.0000 | 1.0000 | 0.6875 |
| Confidence | 0.996810 | 0.996903 | 0.996978 |
| Detection latency | 105.025 s | 120.184 s | 113.545 s |
| Other detector positives | 0 | 0 | 0 |
| Grafana alerts | 0 | 0 | 0 |
| New restarts | 0 | 0 | 0 |
| Request failures | 0 | 0 | 0 |

Aggregate results:

- Valid formal runs: 3
- AD-04R detections: 3
- Detection rate: 100%
- Total attack-phase checkouts: 1,123
- Average baseline rate: 1.57 checkouts/minute
- Average attack rate: 74.70 checkouts/minute
- Average recovery rate: 1.70 checkouts/minute
- Average increase: 47.74x
- Average anomaly grade: 0.8958
- Average confidence: 0.996897
- Average detection latency: 112.918 seconds
- Average frontend attack rate: 299.80 requests/minute
- Total formal request failures: 0

Checkout-abuse traffic was approximately 24.29% of the HTTP-flood request rate.

### 9.6 Checkout-Abuse Conclusion

AD-04R detected the checkout-abuse onset in all three runs while:

- All checkout requests succeeded.
- CPU remained below configured alert thresholds.
- Memory remained below the configured alert threshold.
- No Pod became unavailable.
- No restart count increased.
- No Grafana alert fired.
- No unrelated anomaly detector produced a positive result.

This is the strongest demonstration that business-workflow anomaly detection complements infrastructure monitoring.

Evidence is stored under:

```text
evidence/05-checkout-abuse/
```

---

## 10. Cross-Scenario Comparison

| Scenario | Primary detector or alert | Formal detection result | Grafana resource alerts | Availability impact |
|---|---|---:|---:|---:|
| Endpoint scanning | AD-03 | 3/3 | 0/3 | None |
| HTTP flood | AD-01 | 2/3 | CPU and memory alerts in 3/3 | None |
| Checkout abuse | AD-04R | 3/3 | 0/3 | None |

Main observations:

1. Endpoint scanning was best detected through path diversity in logs.
2. HTTP flood was most consistently visible through CPU and memory metrics.
3. Checkout abuse was best detected through business-operation features.
4. No single detector was sufficient for every abnormal behavior.
5. Combining Grafana alerts and OpenSearch anomaly detection provided broader coverage than either method alone.

---

## 11. Evidence Organization

The evidence directory is organized as:

```text
evidence/
├── 00-system-state-20260617-0859/
├── 01-baseline/
├── 01-opensearch-persistence-test/
├── 02-formal-baseline/
├── 03-endpoint-scanning/
├── 04-http-flood/
└── 05-checkout-abuse/
```

Scenario summary files include:

```text
evidence/03-endpoint-scanning/endpoint-scanning-final-summary.txt
evidence/04-http-flood/http-flood-final-summary.txt
evidence/05-checkout-abuse/checkout-abuse-final-summary.txt
```

Each formal scenario directory contains combinations of:

- Locust CSV statistics
- Locust HTML reports
- Selected result summaries
- Exact phase timestamps
- Pod state before and after
- Restart counts before and after
- OpenSearch phase aggregations
- All detector results
- Positive detector results
- Cross-detector result queries
- Grafana dashboard screenshots
- Grafana alert-history screenshots
- OpenSearch anomaly screenshots

---

## 12. Repository Additions

The repository now includes the following experiment scripts:

```text
experiments/
├── attacks/
│   ├── endpoint-scan-locustfile.py
│   ├── http-flood-locustfile.py
│   └── checkout-abuse-locustfile.py
├── baseline/
│   ├── locustfile.py
│   └── checkout-normal-locustfile.py
└── run-checkout-formal.ps1
```

The monitoring configuration includes:

- Prometheus and Grafana Helm values
- Fluent Bit Helm values
- OpenSearch configuration
- OpenSearch Dashboards configuration
- Detector evidence and configuration backups

The repository also preserves invalid orchestration attempts where useful for traceability. These attempts are clearly marked and excluded from the formal results.

---

## 13. Problems Solved During This Stage

The main technical problems solved were:

- Incorrect or nested application-log parsing
- Missing top-level HTTP fields in OpenSearch
- Fluent Bit parser-chain configuration
- OpenSearch detector initialization delays
- Detector UI and API state inconsistency
- Invalid average aggregation behavior
- Detector recreation under active traffic
- Scenario-specific feature engineering
- Controlled Locust workload creation
- Baseline, attack, and recovery separation
- Continuous checkout baseline design
- Windows PowerShell background-process handling
- Relative path problems in background jobs
- Locust stderr handling
- Blank process exit-code handling
- Formal evidence-directory validation
- Exact ISO and epoch timestamp recording
- Exclusion and documentation of invalid experiment attempts

---

## 14. Current Project Status

### Completed

- Reduced Online Boutique application
- Docker Compose validation
- Kubernetes deployment
- Two-namespace organization
- Prometheus metric collection
- Grafana dashboards
- Grafana alert rules
- Fluent Bit collection
- Fluent Bit structured JSON parsing
- Kubernetes log metadata enrichment
- OpenSearch log storage
- OpenSearch Dashboards data access
- OpenSearch persistence
- Formal normal-traffic baseline
- Four anomaly detectors
- Endpoint-scanning pilot and three formal runs
- HTTP-flood pilot and three formal runs
- Checkout-abuse pilot and three formal runs
- Recovery-period evaluation
- Cross-detector specificity checks
- Scenario-level evidence organization
- Final scenario summary files

### Remaining Work

- Integrate the final experiment results into the thesis report.
- Update the implementation chapter with the corrected Fluent Bit parsing pipeline.
- Add detector configurations and feature definitions to the report.
- Add experiment tables and screenshots.
- Compare rule-based and anomaly-based detection across scenarios.
- Complete the discussion of limitations.
- Finalize the architecture and workflow diagrams.
- Review whether Gmail and Telegram notification delivery should be completed or documented as planned/future work.
- Clean and commit the final repository changes.
- Update the README so it reflects completed experiments rather than planned experiments.

---

## 15. Limitations and Research Notes

The experiment environment is a local, single-node Kubernetes deployment. The results should therefore be interpreted as controlled experimental findings rather than production-scale performance measurements.

OpenSearch Random Cut Forest is an online adaptive model. Repeated exposure to similar patterns may affect later anomaly scores. This was visible in:

- Inconsistent AD-01 HTTP-flood detection
- AD-02R formal non-detection after pilot detection
- The lower AD-04R anomaly grade in checkout-abuse Run 03

The repeated scenarios were intentionally not reset by recreating detectors because the objective was to evaluate the running online system honestly.

The Grafana thresholds were fixed before the formal experiments. They were not lowered to force alerts.

A detector miss in a valid run was preserved as a result rather than rerun for a more favorable outcome.

---

## 16. Main Project Finding

The completed experiments show that security monitoring in a microservice environment benefits from combining infrastructure metrics with application behavior.

- Grafana detected strong resource symptoms during the HTTP flood.
- AD-03 detected endpoint scanning without resource alerts.
- AD-04R detected checkout workflow abuse without resource alerts.
- Other detectors remained quiet during scenario-specific tests.
- No formal scenario caused service unavailability.

The main conclusion from the implementation is:

> Metrics-based monitoring is effective for visible infrastructure pressure, while log-based anomaly detection can identify application-level behavior that does not exceed CPU, memory, restart, or readiness thresholds.

The combination of Prometheus, Grafana, Fluent Bit, OpenSearch, and scenario-specific anomaly features provides broader monitoring coverage than any single monitoring method.
