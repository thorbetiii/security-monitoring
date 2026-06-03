# Progress Note - 2026-06-03

## Milestone

Prometheus, Grafana, OpenSearch, OpenSearch Dashboards, and Fluent Bit were configured and validated for the thesis system. By the end of the day, both the metric monitoring path and the log monitoring path were working.

## Current System Status

The reduced Online Boutique application is already deployed in the `application` namespace and remains stable.

The active application services are:

* `frontend`
* `productcatalogservice`
* `cartservice`
* `redis-cart`
* `checkoutservice`
* `paymentservice`
* `shippingservice`
* `currencyservice`
* `emailservice`

The monitoring components are deployed in the `monitoring` namespace.

## Prometheus and Grafana Work

The Prometheus/Grafana monitoring stack was installed using Helm through `kube-prometheus-stack`.

The following components were deployed:

* Prometheus
* Grafana
* Alertmanager
* Prometheus Operator
* kube-state-metrics

Node Exporter caused a local Docker Desktop Kubernetes compatibility issue due to host filesystem mount behavior. Since the thesis focuses mainly on pod-level and application-level monitoring, Node Exporter was disabled.

## Grafana Dashboard Work

A Grafana dashboard named **Application Monitoring Overview** was created and cleaned.

The dashboard monitors the reduced application through Prometheus metrics.

Final dashboard panels include:

* Running Application Pods
* Application Pod Ready Status
* Pod Restarts
* CPU Usage by Pod
* Memory Usage by Pod
* Top 5 Pods by CPU Usage
* Top 5 Pods by Memory Usage

Network panels were removed because the current Prometheus setup did not expose reliable container network metrics. This was considered acceptable because the first dashboard focuses on baseline application health and resource monitoring.

## Grafana Rule-Based Detection

Grafana alert rules were created for the application namespace. These rules form the first rule-based detection layer of the thesis system.

Created alert rules:

* Application Pod Not Ready
* Application Pod Restart Detected
* Frontend CPU Spike
* Checkout Service CPU Spike
* High CPU Usage by Pod
* High Memory Usage by Pod

These rules are designed to support future attack and abuse scenarios:

* HTTP flood may trigger frontend CPU or general CPU alerts.
* Endpoint scanning may affect frontend resource usage and will later be better analyzed through logs.
* Checkout abuse may trigger checkoutservice CPU or general resource alerts.
* Pod readiness and restart alerts provide general service stability monitoring.

At the time of configuration, the rules were healthy and not firing during normal application operation.

## OpenSearch and OpenSearch Dashboards Work

OpenSearch and OpenSearch Dashboards were deployed in the `monitoring` namespace.

OpenSearch was configured as a single-node local deployment. Security was disabled for the local thesis environment to simplify experimentation and avoid unnecessary authentication/TLS complexity.

An index template was added for application logs:

```text
monitoring/opensearch/application-logs-index-template.json
```

The template ensures future `application-logs-*` indices use:

```json
{
  "number_of_shards": 1,
  "number_of_replicas": 0
}
```

This is necessary because the local OpenSearch deployment only has one node. Without setting replicas to `0`, the index may stay yellow because replica shards cannot be assigned.

## Fluent Bit Work

Fluent Bit was deployed as the Kubernetes log collector.

The log collection pipeline is:

```text
Application pods
→ container log files under /var/log/containers
→ Fluent Bit
→ OpenSearch
→ OpenSearch Dashboards
```

Fluent Bit was configured to collect only logs from the `application` namespace:

```text
/var/log/containers/*_application_*.log
```

Several issues were identified and fixed:

1. Fluent Bit originally started reading log files from the end, so older logs were skipped.
   Fix: added `Read_From_Head On`.

2. The previous tag/match pattern was not compatible with the Kubernetes metadata filter.
   Fix: changed the tag and match pattern to `kube.*`.

3. Fluent Bit had a duplicate `cri` parser definition, which caused a startup warning.
   Fix: removed the duplicate custom parser.

4. The old Fluent Bit database file could preserve previous read positions.
   Fix: changed the database file to:

```text
/var/log/flb_application_v2.db
```

## OpenSearch Log Validation

After the Fluent Bit configuration was fixed, OpenSearch successfully received application logs.

The application log index was created:

```text
application-logs-2026.06.03
```

The index became healthy with:

* status: `green`
* replicas: `0`
* documents successfully indexed

Sample logs were also checked in OpenSearch Dashboards. The logs appeared in the `application-logs-*` data view and included Kubernetes metadata fields such as:

* `kubernetes.namespace_name`
* `kubernetes.pod_name`
* `kubernetes.container_name`
* `log`
* `@timestamp`

This confirms that Fluent Bit is not only forwarding raw logs, but also enriching them with Kubernetes metadata.

## OpenSearch Dashboards Validation

A data view was created in OpenSearch Dashboards:

```text
application-logs-*
```

The time field was set to:

```text
@timestamp
```

The logs were checked in the Discover page. Application logs appeared successfully, proving that the full log monitoring pipeline is working.

## Result

By the end of 2026-06-03, the monitoring foundation was completed.

The system now has:

* A working reduced application deployed on Kubernetes.
* A working Prometheus/Grafana metrics monitoring path.
* A cleaned Grafana application dashboard.
* A set of Grafana rule-based alert rules.
* A working OpenSearch and OpenSearch Dashboards setup.
* A working Fluent Bit log collection pipeline.
* Application logs successfully indexed into OpenSearch.
* Kubernetes metadata available in OpenSearch log documents.

This completes the main observability foundation of the thesis system.

## Current Work Plan Status

* Phase 0 — Scope freeze: DONE
* Phase 1 — Reduced application build and Kubernetes deployment: DONE
* Phase 2 — Prometheus/Grafana monitoring: DONE
* Phase 3 — Grafana rule-based alert rules: DONE
* Phase 4 — OpenSearch and Fluent Bit log monitoring: DONE
* Phase 5 — Bachelor thesis report writing: NEXT
* Phase 6 — Traffic generation and experiments: AFTER report structure is drafted
* Phase 7 — OpenSearch anomaly detection and final evaluation: LATER

## Next Steps

The next major step is to begin writing the bachelor thesis report while the implementation details are still fresh.

Recommended next writing tasks:

1. Draft the system architecture chapter.
2. Draft the implementation chapter.
3. Explain the reduced Online Boutique application and why some services were removed.
4. Explain the Docker Compose and Kubernetes deployment flow.
5. Explain the Prometheus/Grafana metric monitoring path.
6. Explain the Grafana rule-based detection rules.
7. Explain the Fluent Bit/OpenSearch log monitoring path.
8. Prepare placeholders for future experiment results.

After the first report draft is started, the next technical phase will be traffic generation and experiments for:

* HTTP flood
* Endpoint scanning
* Checkout abuse
