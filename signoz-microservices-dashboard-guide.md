# SigNoz Microservices Monitoring Dashboard Guide

## Overview
This guide helps you set up comprehensive monitoring dashboards in SigNoz for microservices during load testing, stress testing, and performance testing scenarios.

## Dashboard Setup

### 1. CPU and Memory Resource Monitoring

#### CPU Usage Query
```sql
-- Average CPU usage per microservice
SELECT 
    service_name,
    AVG(system_cpu_usage) as avg_cpu_usage,
    MAX(system_cpu_usage) as max_cpu_usage
FROM metrics 
WHERE 
    metric_name = 'system_cpu_usage' 
    AND timestamp >= now() - INTERVAL 1 HOUR
GROUP BY service_name
ORDER BY avg_cpu_usage DESC
```

#### Memory Usage Query
```sql
-- Memory usage per microservice
SELECT 
    service_name,
    AVG(process_memory_usage) as avg_memory_mb,
    MAX(process_memory_usage) as max_memory_mb,
    AVG(process_memory_usage) / 1024 / 1024 as avg_memory_gb
FROM metrics 
WHERE 
    metric_name = 'process_memory_usage'
    AND timestamp >= now() - INTERVAL 1 HOUR
GROUP BY service_name
ORDER BY avg_memory_mb DESC
```

### 2. Performance Metrics Queries

#### Response Time Analysis
```sql
-- P95 and P99 response times
SELECT 
    service_name,
    operation,
    quantile(0.95)(duration) as p95_response_time,
    quantile(0.99)(duration) as p99_response_time,
    AVG(duration) as avg_response_time
FROM traces 
WHERE 
    timestamp >= now() - INTERVAL 1 HOUR
GROUP BY service_name, operation
ORDER BY p99_response_time DESC
```

#### Request Rate and Error Rate
```sql
-- Request rate and error percentage
SELECT 
    service_name,
    COUNT(*) as total_requests,
    COUNT(*) / 3600 as requests_per_second,
    SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END) as error_count,
    (SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) as error_percentage
FROM traces 
WHERE 
    timestamp >= now() - INTERVAL 1 HOUR
GROUP BY service_name
ORDER BY error_percentage DESC
```

#### Throughput Analysis
```sql
-- Throughput per endpoint
SELECT 
    service_name,
    http_route,
    COUNT(*) as request_count,
    COUNT(*) / 60 as requests_per_minute,
    AVG(duration) as avg_duration_ms
FROM traces 
WHERE 
    timestamp >= now() - INTERVAL 1 HOUR
    AND kind = 'server'
GROUP BY service_name, http_route
ORDER BY request_count DESC
```

### 3. Load Testing Specific Queries

#### Concurrent Users Impact
```sql
-- Performance degradation under load
SELECT 
    toStartOfMinute(timestamp) as time_bucket,
    service_name,
    COUNT(*) as concurrent_requests,
    AVG(duration) as avg_response_time,
    quantile(0.95)(duration) as p95_response_time
FROM traces 
WHERE 
    timestamp >= now() - INTERVAL 2 HOURS
GROUP BY time_bucket, service_name
ORDER BY time_bucket, avg_response_time DESC
```

#### Database Connection Pool Monitoring
```sql
-- Database connection metrics
SELECT 
    service_name,
    AVG(db_connection_pool_active) as avg_active_connections,
    MAX(db_connection_pool_active) as max_active_connections,
    AVG(db_connection_pool_idle) as avg_idle_connections
FROM metrics 
WHERE 
    metric_name LIKE '%db_connection%'
    AND timestamp >= now() - INTERVAL 1 HOUR
GROUP BY service_name
```

### 4. Resource Utilization Queries

#### JVM Metrics (for Java services)
```sql
-- JVM heap usage
SELECT 
    service_name,
    AVG(jvm_memory_heap_used) / 1024 / 1024 as avg_heap_used_mb,
    MAX(jvm_memory_heap_used) / 1024 / 1024 as max_heap_used_mb,
    AVG(jvm_memory_heap_max) / 1024 / 1024 as heap_max_mb,
    (AVG(jvm_memory_heap_used) * 100.0 / AVG(jvm_memory_heap_max)) as heap_usage_percentage
FROM metrics 
WHERE 
    metric_name = 'jvm_memory_heap_used'
    AND timestamp >= now() - INTERVAL 1 HOUR
GROUP BY service_name
```

#### Garbage Collection Impact
```sql
-- GC performance impact
SELECT 
    service_name,
    SUM(jvm_gc_collection_seconds_count) as gc_collections,
    SUM(jvm_gc_collection_seconds_sum) as total_gc_time_seconds,
    AVG(jvm_gc_collection_seconds_sum) as avg_gc_time
FROM metrics 
WHERE 
    metric_name LIKE '%jvm_gc%'
    AND timestamp >= now() - INTERVAL 1 HOUR
GROUP BY service_name
ORDER BY total_gc_time_seconds DESC
```

## Dashboard Panels Configuration

### Panel 1: Service Health Overview
- **Type**: Table
- **Query**: Service status with CPU, Memory, Error Rate
- **Refresh**: 30s
- **Thresholds**: 
  - CPU > 80% (Red)
  - Memory > 85% (Red)
  - Error Rate > 5% (Red)

### Panel 2: Response Time Heatmap
- **Type**: Heatmap
- **Query**: Response time distribution over time
- **X-axis**: Time
- **Y-axis**: Response time buckets

### Panel 3: Request Rate Timeline
- **Type**: Time Series
- **Query**: Requests per second per service
- **Stack**: True

### Panel 4: Error Rate Gauge
- **Type**: Gauge
- **Query**: Overall error percentage
- **Thresholds**: 0-1% (Green), 1-5% (Yellow), >5% (Red)

## Alert Configuration

### 1. Mattermost Integration Setup

#### Webhook Configuration
```json
{
  "webhook_url": "https://your-mattermost-instance.com/hooks/your-webhook-id",
  "channel": "#monitoring-alerts",
  "username": "SigNoz-Alerts",
  "icon_emoji": ":warning:"
}
```

#### Alert Rules for Mattermost

##### High CPU Usage Alert
```yaml
alert: HighCPUUsage
expr: avg(system_cpu_usage) by (service_name) > 80
for: 2m
labels:
  severity: warning
  service: "{{ $labels.service_name }}"
annotations:
  summary: "High CPU usage detected"
  description: "Service {{ $labels.service_name }} has CPU usage above 80% for more than 2 minutes"
  mattermost_title: "🚨 High CPU Alert"
  mattermost_text: |
    **Service**: {{ $labels.service_name }}
    **CPU Usage**: {{ $value }}%
    **Threshold**: 80%
    **Duration**: 2+ minutes
```

##### High Memory Usage Alert
```yaml
alert: HighMemoryUsage
expr: (process_memory_usage / 1024 / 1024 / 1024) > 2
for: 5m
labels:
  severity: critical
annotations:
  summary: "High memory usage detected"
  description: "Service {{ $labels.service_name }} memory usage exceeds 2GB"
  mattermost_title: "🔥 Critical Memory Alert"
```

##### High Error Rate Alert
```yaml
alert: HighErrorRate
expr: (rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])) * 100 > 5
for: 1m
labels:
  severity: critical
annotations:
  summary: "High error rate detected"
  description: "Service {{ $labels.service_name }} error rate is {{ $value }}%"
```

### 2. Slack Integration Setup

#### Slack Webhook Configuration
```json
{
  "webhook_url": "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK",
  "channel": "#alerts",
  "username": "SigNoz",
  "icon_emoji": ":chart_with_upwards_trend:"
}
```

#### Slack Alert Template
```yaml
slack_configs:
- api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
  channel: '#monitoring'
  title: 'SigNoz Alert: {{ .GroupLabels.alertname }}'
  text: |
    {{ range .Alerts }}
    *Alert:* {{ .Annotations.summary }}
    *Description:* {{ .Annotations.description }}
    *Service:* {{ .Labels.service_name }}
    *Severity:* {{ .Labels.severity }}
    *Time:* {{ .StartsAt.Format "2006-01-02 15:04:05" }}
    {{ end }}
```

## Load Testing Dashboard Panels

### Real-time Load Testing Metrics
```sql
-- Active load test monitoring
SELECT 
    toStartOfMinute(timestamp) as minute,
    service_name,
    COUNT(*) as requests_per_minute,
    AVG(duration) as avg_response_time,
    quantile(0.95)(duration) as p95_response_time,
    SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END) as errors
FROM traces 
WHERE 
    timestamp >= now() - INTERVAL 30 MINUTES
GROUP BY minute, service_name
ORDER BY minute DESC
```

### Resource Saturation Detection
```sql
-- Identify resource bottlenecks
SELECT 
    service_name,
    AVG(system_cpu_usage) as cpu_usage,
    AVG(process_memory_usage) / 1024 / 1024 as memory_mb,
    AVG(db_connection_pool_active) as active_db_connections,
    COUNT(*) as request_volume
FROM metrics m
JOIN traces t ON m.service_name = t.service_name
WHERE 
    m.timestamp >= now() - INTERVAL 15 MINUTES
    AND t.timestamp >= now() - INTERVAL 15 MINUTES
GROUP BY service_name
HAVING cpu_usage > 70 OR memory_mb > 1024 OR active_db_connections > 50
```

## GKE-Specific PromQL Queries & Visualizations

### 1. CPU Monitoring Queries

#### Pod CPU Usage (Recommended Chart: Time Series)
```promql
# CPU usage per pod
rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m]) * 100

# CPU usage by namespace
sum(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) by (namespace) * 100

# CPU throttling detection
rate(container_cpu_cfs_throttled_seconds_total[5m]) > 0
```

#### CPU Requests vs Limits (Recommended Chart: Bar Gauge)
```promql
# CPU request utilization percentage
(rate(container_cpu_usage_seconds_total{container!="POD"}[5m]) / on(pod) kube_pod_container_resource_requests{resource="cpu"}) * 100

# CPU limit utilization percentage  
(rate(container_cpu_usage_seconds_total{container!="POD"}[5m]) / on(pod) kube_pod_container_resource_limits{resource="cpu"}) * 100

# Pods without CPU limits
kube_pod_container_resource_limits{resource="cpu"} == 0
```

#### Node CPU Analysis (Recommended Chart: Heatmap)
```promql
# Node CPU usage
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance) * 100)

# CPU usage by node and pod
sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) by (instance, pod)

# Top CPU consuming pods
topk(10, sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) by (pod, namespace))
```

### 2. Memory Monitoring Queries

#### Pod Memory Usage (Recommended Chart: Time Series + Table)
```promql
# Memory usage per pod
container_memory_usage_bytes{container!="POD",container!=""}

# Memory usage percentage of requests
(container_memory_usage_bytes{container!="POD"} / on(pod) kube_pod_container_resource_requests{resource="memory"}) * 100

# Memory usage percentage of limits
(container_memory_usage_bytes{container!="POD"} / on(pod) kube_pod_container_resource_limits{resource="memory"}) * 100
```

#### Memory Pressure Detection (Recommended Chart: Stat Panel)
```promql
# Pods approaching memory limits (>80%)
(container_memory_usage_bytes{container!="POD"} / on(pod) kube_pod_container_resource_limits{resource="memory"}) > 0.8

# Memory working set vs RSS
container_memory_working_set_bytes{container!="POD"} - container_memory_rss{container!="POD"}

# OOM killed containers
increase(kube_pod_container_status_restarts_total[1h]) and on(pod) kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}
```

#### Node Memory Analysis (Recommended Chart: Gauge + Time Series)
```promql
# Node memory utilization
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Available memory per node
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024

# Memory pressure by node
rate(node_vmstat_pgmajfault[5m])
```

### 3. GKE Cluster Monitoring

#### Cluster Resource Overview (Recommended Chart: Stat Panel Grid)
```promql
# Total cluster CPU capacity
sum(kube_node_status_allocatable{resource="cpu"})

# Total cluster memory capacity  
sum(kube_node_status_allocatable{resource="memory"}) / 1024 / 1024 / 1024

# Cluster CPU utilization
(sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) / sum(kube_node_status_allocatable{resource="cpu"})) * 100

# Cluster memory utilization
(sum(container_memory_usage_bytes{container!="POD"}) / sum(kube_node_status_allocatable{resource="memory"})) * 100
```

#### Pod Scheduling & Health (Recommended Chart: Table + Stat)
```promql
# Pending pods
kube_pod_status_phase{phase="Pending"}

# Failed pods
kube_pod_status_phase{phase="Failed"}

# Pods without resource requests
kube_pod_container_resource_requests{resource="cpu"} == 0 or kube_pod_container_resource_requests{resource="memory"} == 0

# Pod restart rate
rate(kube_pod_container_status_restarts_total[5m])
```

### 4. HPA & VPA Monitoring

#### Horizontal Pod Autoscaler (Recommended Chart: Time Series)
```promql
# HPA current replicas vs desired
kube_horizontalpodautoscaler_status_current_replicas

# HPA target CPU utilization
kube_horizontalpodautoscaler_spec_target_cpu_utilization_percentage

# HPA scaling events
increase(kube_horizontalpodautoscaler_status_desired_replicas[5m])
```

#### Vertical Pod Autoscaler (Recommended Chart: Bar Chart)
```promql
# VPA recommendations vs current requests
kube_vpa_status_recommendation{resource="cpu", target_type="lowerBound"}
kube_vpa_status_recommendation{resource="memory", target_type="lowerBound"}
```

### 5. Network & Storage I/O

#### Network Monitoring (Recommended Chart: Time Series)
```promql
# Network I/O per pod
rate(container_network_receive_bytes_total[5m])
rate(container_network_transmit_bytes_total[5m])

# Network errors
rate(container_network_receive_errors_total[5m])
rate(container_network_transmit_errors_total[5m])
```

#### Storage I/O (Recommended Chart: Heatmap)
```promql
# Disk I/O per container
rate(container_fs_reads_bytes_total[5m])
rate(container_fs_writes_bytes_total[5m])

# Disk usage percentage
(container_fs_usage_bytes / container_fs_limit_bytes) * 100
```

## GKE Dashboard Panel Configurations

### Panel 1: Cluster Overview (Stat Panel Grid - 2x2)
```promql
# Queries for 4 stat panels
sum(kube_node_status_condition{condition="Ready",status="true"})  # Ready Nodes
sum(kube_pod_status_phase{phase="Running"})  # Running Pods  
(sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) / sum(kube_node_status_allocatable{resource="cpu"})) * 100  # CPU Usage %
(sum(container_memory_usage_bytes{container!="POD"}) / sum(kube_node_status_allocatable{resource="memory"})) * 100  # Memory Usage %
```

### Panel 2: CPU Usage by Namespace (Time Series - Stacked)
```promql
sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) by (namespace) * 100
```

### Panel 3: Memory Usage Heatmap (Heatmap)
```promql
sum(container_memory_usage_bytes{container!="POD"}) by (pod, namespace) / 1024 / 1024
```

### Panel 4: Top Resource Consumers (Table)
```promql
# CPU Top 10
topk(10, sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) by (pod, namespace))

# Memory Top 10  
topk(10, sum(container_memory_usage_bytes{container!="POD"}) by (pod, namespace))
```

### Panel 5: Pod Health Status (Pie Chart)
```promql
sum(kube_pod_status_phase) by (phase)
```

### Panel 6: Resource Requests vs Limits (Bar Gauge)
```promql
# CPU Requests vs Usage
sum(kube_pod_container_resource_requests{resource="cpu"}) by (namespace)
sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) by (namespace)

# Memory Requests vs Usage
sum(kube_pod_container_resource_requests{resource="memory"}) by (namespace) / 1024 / 1024 / 1024
sum(container_memory_usage_bytes{container!="POD"}) by (namespace) / 1024 / 1024 / 1024
```

## Chart Type Recommendations

### CPU Monitoring Charts
- **Time Series**: CPU usage trends, throttling events
- **Heatmap**: CPU usage distribution across pods/nodes
- **Bar Gauge**: CPU requests vs limits comparison
- **Stat Panel**: Current CPU utilization percentage

### Memory Monitoring Charts  
- **Time Series**: Memory usage over time, memory leaks detection
- **Table**: Top memory consumers with sorting
- **Gauge**: Memory pressure indicators
- **Bar Chart**: Memory requests vs limits vs usage

### Cluster Health Charts
- **Stat Panel Grid**: Key cluster metrics (nodes, pods, utilization)
- **Pie Chart**: Pod status distribution
- **Table**: Resource allocation by namespace
- **Time Series**: Scaling events and trends

### Load Testing Specific Charts
- **Heatmap**: Response time distribution during load tests
- **Time Series (Multi-axis)**: RPS vs Response Time vs Error Rate
- **Bar Chart**: Resource usage before/during/after tests
- **Gauge**: Real-time performance indicators

## GKE-Specific Alert Rules

### CPU Alerts
```yaml
# High CPU usage per pod
- alert: PodHighCPUUsage
  expr: (rate(container_cpu_usage_seconds_total{container!="POD"}[5m]) / on(pod) kube_pod_container_resource_limits{resource="cpu"}) > 0.8
  for: 5m
  
# CPU throttling
- alert: CPUThrottling  
  expr: rate(container_cpu_cfs_throttled_seconds_total[5m]) > 0.1
  for: 2m
```

### Memory Alerts
```yaml
# High memory usage
- alert: PodHighMemoryUsage
  expr: (container_memory_usage_bytes{container!="POD"} / on(pod) kube_pod_container_resource_limits{resource="memory"}) > 0.9
  for: 3m

# OOM kills
- alert: PodOOMKilled
  expr: increase(kube_pod_container_status_restarts_total[5m]) and on(pod) kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}
```

### Node Alerts
```yaml
# Node resource pressure
- alert: NodeHighResourceUsage
  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.85
  for: 5m
```

### Advanced CPU & Memory Analysis

#### CPU Performance Deep Dive (Recommended Chart: Multi-axis Time Series)
```promql
# CPU usage vs CPU throttling correlation
rate(container_cpu_usage_seconds_total{container!="POD"}[5m]) and rate(container_cpu_cfs_throttled_seconds_total[5m])

# CPU usage efficiency (usage vs requests ratio)
(rate(container_cpu_usage_seconds_total{container!="POD"}[5m]) / on(pod) kube_pod_container_resource_requests{resource="cpu"}) * 100

# CPU steal time (indicates node overcommitment)
rate(node_cpu_seconds_total{mode="steal"}[5m]) * 100

# Context switches per second (high values indicate CPU contention)
rate(node_context_switches_total[5m])
```

#### Memory Deep Analysis (Recommended Chart: Stacked Time Series)
```promql
# Memory breakdown by type
container_memory_rss{container!="POD"}  # Resident Set Size
container_memory_cache{container!="POD"}  # Page cache
container_memory_swap{container!="POD"}  # Swap usage

# Memory allocation rate
rate(container_memory_mapped_file[5m])

# Memory pressure indicators
rate(container_memory_failures_total{type="pgmajfault"}[5m])  # Major page faults
rate(node_vmstat_pgpgin[5m])  # Pages read from disk
rate(node_vmstat_pgpgout[5m])  # Pages written to disk
```

#### GKE Workload Monitoring (Recommended Chart: Table + Heatmap)
```promql
# Deployment resource efficiency
(sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) by (deployment) / sum(kube_deployment_spec_replicas) by (deployment)) * 100

# StatefulSet resource patterns
sum(container_memory_usage_bytes{container!="POD"}) by (statefulset) / 1024 / 1024 / 1024

# DaemonSet resource consumption per node
sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) by (daemonset, instance)

# Job completion efficiency
kube_job_status_completion_time - kube_job_status_start_time
```

#### Resource Waste Detection (Recommended Chart: Bar Chart)
```promql
# Over-provisioned CPU (low utilization)
(kube_pod_container_resource_requests{resource="cpu"} - rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) > 0.5

# Over-provisioned Memory (low utilization)  
(kube_pod_container_resource_requests{resource="memory"} - container_memory_usage_bytes{container!="POD"}) / 1024 / 1024 > 500

# Under-provisioned resources (hitting limits)
(container_memory_usage_bytes{container!="POD"} / on(pod) kube_pod_container_resource_limits{resource="memory"}) > 0.95
```

## Advanced Monitoring Queries
```sql
-- Service call patterns and dependencies
SELECT 
    parent_service_name,
    child_service_name,
    COUNT(*) as call_count,
    AVG(duration) as avg_call_duration,
    SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END) as failed_calls
FROM traces 
WHERE 
    timestamp >= now() - INTERVAL 1 HOUR
    AND parent_service_name != child_service_name
GROUP BY parent_service_name, child_service_name
ORDER BY call_count DESC
```

### Performance Regression Detection
```sql
-- Compare current vs previous hour performance
WITH current_hour AS (
    SELECT 
        service_name,
        AVG(duration) as current_avg_duration
    FROM traces 
    WHERE timestamp >= now() - INTERVAL 1 HOUR
    GROUP BY service_name
),
previous_hour AS (
    SELECT 
        service_name,
        AVG(duration) as previous_avg_duration
    FROM traces 
    WHERE timestamp >= now() - INTERVAL 2 HOUR 
        AND timestamp < now() - INTERVAL 1 HOUR
    GROUP BY service_name
)
SELECT 
    c.service_name,
    c.current_avg_duration,
    p.previous_avg_duration,
    ((c.current_avg_duration - p.previous_avg_duration) / p.previous_avg_duration * 100) as performance_change_percent
FROM current_hour c
JOIN previous_hour p ON c.service_name = p.service_name
WHERE ((c.current_avg_duration - p.previous_avg_duration) / p.previous_avg_duration * 100) > 20
ORDER BY performance_change_percent DESC
```

## Dashboard Export/Import

### Export Dashboard Configuration
```bash
# Export dashboard as JSON
curl -X GET "http://your-signoz-instance:3301/api/v1/dashboards/export/{dashboard_id}" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -o microservices_dashboard.json
```

### Import Dashboard
```bash
# Import dashboard
curl -X POST "http://your-signoz-instance:3301/api/v1/dashboards/import" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d @microservices_dashboard.json
```

## Best Practices

### 1. Dashboard Organization
- Group related metrics in logical panels
- Use consistent color schemes across panels
- Set appropriate refresh intervals (30s for real-time, 5m for historical)
- Add descriptions to complex queries

### 2. Alert Tuning
- Start with conservative thresholds and adjust based on baseline
- Use different severity levels (info, warning, critical)
- Implement alert fatigue prevention with proper grouping
- Test alerts during low-traffic periods

### 3. Performance Optimization
- Use time-based partitioning for large datasets
- Implement proper indexing on frequently queried fields
- Cache dashboard results for better performance
- Use sampling for high-volume traces

### 4. Load Testing Integration
- Create dedicated dashboards for load testing sessions
- Use annotations to mark test start/end times
- Monitor both application and infrastructure metrics
- Set up automated reports for test results

## Troubleshooting Common Issues

### High Memory Usage
```sql
-- Identify memory leaks
SELECT 
    service_name,
    toStartOfHour(timestamp) as hour,
    AVG(process_memory_usage) as avg_memory,
    MAX(process_memory_usage) as max_memory
FROM metrics 
WHERE 
    metric_name = 'process_memory_usage'
    AND timestamp >= now() - INTERVAL 24 HOURS
GROUP BY service_name, hour
ORDER BY service_name, hour
```

### Slow Database Queries
```sql
-- Database performance analysis
SELECT 
    db_statement,
    COUNT(*) as query_count,
    AVG(duration) as avg_duration,
    MAX(duration) as max_duration
FROM traces 
WHERE 
    kind = 'client'
    AND db_system IS NOT NULL
    AND timestamp >= now() - INTERVAL 1 HOUR
GROUP BY db_statement
HAVING avg_duration > 1000
ORDER BY avg_duration DESC
```

This comprehensive guide provides everything needed to set up effective monitoring for microservices during load testing scenarios with proper alerting integration.
