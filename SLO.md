# DumbKV Service Level Objectives (SLOs)

## Executive Summary

DumbKV is a critical key-value store serving application data. This document defines comprehensive SLOs based on available Prometheus metrics to ensure reliability, performance, and operational health.

---

## Primary User-Facing SLOs

### 1. Availability SLO

**Objective:** 99.9% request success rate
**SLI:** Successful HTTP responses as percentage of total requests

**Measurement (Prometheus):**

```prometheus
1 - (
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
) >= 0.999
```

**Target:** 99.9% monthly (≈43 minutes error budget)
**Scope:** All HTTP endpoints, excluding 4xx client errors

---

### 2. Latency SLO

**Objective:** P99 latency under 100ms for KV operations
**SLI:** Request duration from histogram metrics

**Measurement (Prometheus):**

```prometheus
# Primary SLO - P99 < 100ms
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) < 0.1

# Secondary targets
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) < 0.05  # P95 < 50ms
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m])) < 0.02  # P50 < 20ms
```

**Target:**

* P99: < 100ms (1% error budget)
* P95: < 50ms
* P50: < 20ms

---

### 3. Error Rate SLO

**Objective:** Server errors below 0.1%
**SLI:** HTTP 5xx errors as percentage of total requests

**Measurement (Prometheus):**

```prometheus
sum(rate(http_requests_total{status=~"5.."}[5m])) /
sum(rate(http_requests_total[5m])) < 0.001
```

**Target:** < 0.1% 5xx errors
**Alert Threshold:** > 0.1% for 5 minutes

---

## Resource & Infrastructure SLOs

### 4. Memory Utilization SLO

**Objective:** Prevent memory exhaustion
**SLI:** Resident memory usage

**Measurement (Prometheus):**

```prometheus
process_resident_memory_bytes < (450 * 1024 * 1024)  # 450MB threshold
```

**Target:** < 450MB resident memory
**Rationale:** Leave buffer before container limits

---

### 5. File Descriptor SLO

**Objective:** Avoid file descriptor exhaustion
**SLI:** Open file descriptors vs maximum

**Measurement (Prometheus):**

```prometheus
process_open_fds / process_max_fds < 0.8
```

**Target:** < 80% file descriptor usage

---

### 6. GC Health SLO

**Objective:** Prevent memory leaks
**SLI:** Uncollectable objects and collection frequency

**Measurement (Prometheus):**

```prometheus
# Alert on memory leaks
rate(python_gc_objects_uncollectable_total[1h]) > 0

# GC pressure monitoring
rate(python_gc_collections_total[5m]) < 20  # < 20 collections/sec
```

**Target:** Zero uncollectable objects, < 20 GCs/sec

---

## Error Budget Policy

### Monthly Allocation

| SLO          | Target      | Error Budget | Time Equivalent |
| ------------ | ----------- | ------------ | --------------- |
| Availability | 99.9%       | 0.1%         | 43 minutes      |
| Latency      | P99 < 100ms | 1%           | 7.2 hours       |
| Error Rate   | < 0.1%      | 0.1%         | 43 minutes      |

### Burn Rate Alerts

```yaml
- alert: HighErrorBudgetBurn
  expr: |
    (sum(rate(http_requests_total{status=~"5.."}[1h])) /
    (sum(rate(http_requests_total[1h])) * 0.001)) > 0.02
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Burning 2% of monthly error budget per hour"

- alert: CriticalLatencySLO
  expr: |
    histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 0.1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "P99 latency exceeding 100ms SLO"
```

### Escalation Matrix

| Budget Consumption | Action                | Notification     |
| ------------------ | --------------------- | ---------------- |
| < 25%              | Normal operations     | Team channel     |
| 25-50%             | Review recent changes | Engineering lead |
| 50-75%             | Feature freeze        | Director level   |
| > 75%              | All-hands incident    | Executive team   |

---

## Monitoring & Implementation

### SLO Dashboard Queries

```prometheus
# 30-day availability
1 - (
  sum(increase(http_requests_total{status=~"5.."}[30d]))
  /
  sum(increase(http_requests_total[30d]))
)

# Error budget remaining
max(0, 1 - (
  sum(increase(http_requests_total{status=~"5.."}[30d]))
  /
  (sum(increase(http_requests_total[30d])) * 0.001)
))

# Request volume tracking
sum(rate(http_requests_total[5m]))
```

### Resource Health Dashboard

```prometheus
# Memory trend in MB
process_resident_memory_bytes / (1024 * 1024)

# FD usage percentage
(process_open_fds / process_max_fds) * 100

# GC activity
rate(python_gc_collections_total[5m])
```

---

## Review & Maintenance

### Weekly Reviews

* Error budget consumption
* Latency distribution changes
* Resource utilization trends

### Monthly Reports

* SLO compliance status
* Incident impact analysis
* Target adjustment recommendations

---

## Success Criteria

* 99.9% availability maintained for 3 consecutive months
* P99 latency consistently under 100ms
* Zero unplanned downtime incidents
* Reduced alert fatigue through SLO-based alerting
