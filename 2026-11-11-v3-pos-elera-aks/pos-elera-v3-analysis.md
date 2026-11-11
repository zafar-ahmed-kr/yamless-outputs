# pos-elera-sales-compliance — YAMLess v3 AKS Analysis
### All fixes through issues #34–#36 applied. Comparison against manual analysis.

**Repo:** `krogertechnology/pos-elera-sales-compliance`
**Target:** Azure Kubernetes Service (AKS)
**YAMLess version:** develop @ a758234
**Date:** 2026-11-11

---

## What Changed v2 → v3

| Fix | Issue | v2 | v3 |
|-----|-------|----|----|
| Secret denylist | #34 | 42 secrets — includes `GF_SECURITY_ADMIN_PASSWORD`, `SWAGGER_URL`, `SWAGGER_CONFIG_URL` | 39 secrets — Grafana/Swagger vars filtered |
| Cosmos DB module | #35 | MongoDB detected, no Terraform resource generated | `azurerm_cosmosdb_account` module generated |
| Secret count warning | #36 | No warning | ⚠️ "High secret count (39)" warning emitted |

---

## YAMLess v3 Profile

```json
{
  "runtime": "java",
  "shape": "http-service",
  "port": 8080,
  "health_check_path": "/actuator/health",
  "mem_limit": "1152Mi",
  "mem_request": "256Mi",
  "database": "mongodb",
  "cache": true,
  "queue": true,
  "min_replicas": 1,
  "max_replicas": 10,
  "secrets": 39
}
```

---

## Infrastructure Generated (Terraform modules)

| Module | Resource | Config |
|--------|----------|--------|
| `cosmos` | `azurerm_cosmosdb_account` | kind=MongoDB, server_version=4.2, throughput=autoscale, max_ru=10000, consistency=BoundedStaleness |
| `servicebus` | `azurerm_servicebus_namespace` | SKU=Standard, TLS 1.2, local_auth=disabled, public_access=disabled |
| `redis` | `azurerm_redis_cache` | SKU=Premium P1, public_access=disabled |
| `keyvault` | `azurerm_key_vault` | RBAC-based, secrets: mongodb-url, servicebus-connection-string, redis-url + 36 app secrets |
| `aks_cluster` | `azurerm_kubernetes_cluster` | OIDC, workload identity |
| `vnet` | `azurerm_virtual_network` | Private subnets |

---

## Kubernetes Deployment (key fields)

```yaml
containers:
  - name: pos-elera-sales-compliance
    ports:
      - containerPort: 8080
    livenessProbe:
      httpGet:
        path: /actuator/health
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /actuator/health
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 3
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 1152Mi
```

---

## Full Comparison Against Manual Analysis

| # | Manual Analysis Finding | v1 | v2 | v3 | Status |
|---|-------------------------|----|----|----|----|
| 1 | MongoDB → Cosmos DB for MongoDB | ❌ no detection | ✅ detected | ✅ **module generated** | **Fixed** |
| 2 | RabbitMQ → Azure Service Bus | ❌ | ✅ | ✅ | Fixed in v2 |
| 3 | Redis Cache → Azure Cache for Redis | ❌ | ✅ | ✅ | Fixed in v2 |
| 4 | Health check path `/actuator/health` | ❌ `/health` | ✅ | ✅ | Fixed in v2 (#28) |
| 5 | Memory limit `1152Mi` from Helm | ❌ default 512Mi | ✅ | ✅ | Fixed in v2 (#29) |
| 6 | Memory request `256Mi` from Helm | ❌ default 256Mi | ✅ | ✅ | Fixed in v2 (#29) |
| 7 | Min replicas from Helm | ❌ | ⚠️ no `replicaCount` in this repo's Helm | ⚠️ same | Not fixable — set via env-specific override outside repo |
| 8 | Grafana/Swagger vars excluded from KV | ❌ included | ❌ included | ✅ **filtered** | **Fixed (#34)** |
| 9 | MONGODB_URI / SPRING_DATA_MONGODB_URI deduplication | ❌ | ❌ | ✅ **infra_managed** | **Fixed (#35)** |
| 10 | High secret count warning | ❌ | ❌ | ✅ **39 flagged** | **Fixed (#36)** |
| 11 | AMQP direct reply-to migration risk (RabbitMQ→Service Bus) | ❌ | ❌ | ❌ | Open — #30, absorbed into #37 |
| 12 | JMX / management secondary port | ❌ | ❌ | ❌ | Open — #32, absorbed into #37 |
| 13 | Spring Cloud Config startup dependency | ❌ | ❌ | ❌ | Open — #33, absorbed into #37 |

---

## Secret Delta: v2 → v3

**Removed by denylist (#34):**
- `GF_SECURITY_ADMIN_PASSWORD` — Grafana admin password, not an app secret
- `SWAGGER_URL` — Swagger docs URL
- `SWAGGER_CONFIG_URL` — Swagger config URL

**Deduped by infra_managed (#35):**
- `MONGODB_URI` — now covered by `mongodb-url` KV secret from Cosmos module
- `SPRING_DATA_MONGODB_URI` — same

**Net change:** 42 → 39 secrets in Key Vault

**Warning triggered (#36):**
> "High secret count (39) detected. Review whether all env vars need to be in Key Vault — consider grouping with a secrets manager pattern or filtering observability vars."

The 39 remaining secrets are legitimate app secrets — PingFederate/OAuth OIDC endpoints, service URLs, API keys, and credentials — not noise. The warning is correctly advisory rather than blocking.

---

## Cost Estimate

| Environment | Monthly (low–high) | Annual |
|-------------|-------------------|--------|
| Dev | $170 – $245 | $2,040 – $2,940 |
| Staging | $392 – $542 | $4,704 – $6,504 |
| Production | $1,217 – $1,867 | $14,604 – $22,404 |

**Production breakdown:**

| Resource | Cost |
|----------|------|
| AKS Cluster | $600/mo |
| Cosmos DB (MongoDB) | $200–$800/mo (autoscale 10,000 RU) |
| Redis Cache | $370/mo (Premium P1) |
| Service Bus | $32–$82/mo (Standard) |
| Key Vault | $15/mo |

---

## Remaining Gaps (all scoped to #37)

### #30 — AMQP direct reply-to incompatibility
YAMLess maps `spring-rabbit` → Azure Service Bus correctly at the provisioning level. It does not surface the protocol mismatch: RabbitMQ uses AMQP 0-9-1; Service Bus uses AMQP 1.0. Apps using `amq.rabbitmq.reply-to` or `RabbitTemplate.convertSendAndReceive()` for direct reply-to patterns require code changes — a silent migration risk.

**Fix:** Migration Risk Evaluator in #37 — static table entry `(spring-rabbit, azure) → "direct reply-to unsupported"`.

### #32 — JMX / management port missing
The Dockerfile exposes a secondary JMX/management port. Only `containerPort: 8080` appears in the generated Deployment. Services or NetworkPolicy rules for the management port are absent.

**Fix:** Runtime Enricher in #37 — read all `EXPOSE` lines from Dockerfile; read `management.server.port` from `application.yml`.

### #33 — Spring Cloud Config startup dependency invisible
`CLOUD_CONFIG_URL` is correctly captured as a secret (it appears in the deployment env vars). But YAMLess has no concept that this means the pod will fail to start if the config server is unreachable. No init container, no topology annotation, no warning.

**Fix:** Runtime Enricher in #37 — `spring-cloud-starter-config` in pom.xml → flag as startup dependency → emit warning `"App depends on external Spring Cloud Config server at CLOUD_CONFIG_URL — ensure it is reachable before pod starts"`.

---

*YAMLess — https://github.com/zafar-ahmed-kr/YAMLess*
*Date: 2026-11-11*
