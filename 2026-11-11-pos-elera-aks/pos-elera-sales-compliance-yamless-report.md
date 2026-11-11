# YAMLess: Generating Azure Infrastructure from Code
### Case Study — krogertechnology/pos-elera-sales-compliance (all fixes through #36)

---

## What is YAMLess?

YAMLess is an **Infrastructure from Code (IFC)** tool. Given a code repository, it produces a complete, policy-validated Terraform workspace — with no configuration files, no schema to fill in, and no IaC expertise required from the developer.

The pipeline has four stages:

```
Repo on disk
    │
    ▼
┌─────────────────────┐
│  1. Static Analyzer │  Reads Dockerfile, pom.xml, .env files, Helm values,
│                     │  Spring Boot YAML, source code (Java @Value, env refs).
│                     │  Produces a typed AppProfile with confidence scores.
└──────────┬──────────┘
           │  (fires only when any field is low/medium confidence)
           ▼
┌─────────────────────┐
│  2. LLM Gap-Filler  │  Claude reads relevant source files and fills in what
│                     │  static analysis couldn't determine — via structured
│                     │  tool use only, no free-form parsing.
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  3. Golden Resolver │  Loads golden-profiles/<resource>.json — per-env
│                     │  sizing standards, cost estimate, governance gates.
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  4. Renderer        │  Jinja2 root templates + static Terraform modules →
│                     │  ready-to-apply workspace. Outputs AKS + K8s manifests.
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  5. Validator       │  checkov policy-as-code. Security posture is enforced
│                     │  by static module files — the LLM cannot affect it.
└─────────────────────┘
```

---

## What Changed Since v2

This run incorporates six fixes shipped across issues [#28](https://github.com/zafar-ahmed-kr/YAMLess/issues/28), [#29](https://github.com/zafar-ahmed-kr/YAMLess/issues/29), [#31](https://github.com/zafar-ahmed-kr/YAMLess/issues/31), [#34](https://github.com/zafar-ahmed-kr/YAMLess/issues/34), [#35](https://github.com/zafar-ahmed-kr/YAMLess/issues/35), and [#36](https://github.com/zafar-ahmed-kr/YAMLess/issues/36), all merged to main on 2026-11-11.

| Issue | Fix | Effect on this repo |
|-------|-----|---------------------|
| #28 | Read `management.endpoints.web.base-path` from Spring Boot YAML; use `spring-boot-starter-actuator` as hint | `health_check_path: /health` → `/actuator/health` |
| #29 | Extract `resources.limits/requests.memory` from Helm `values.yaml`; fallback to `-Xmx` inference | `mem_limit: null` → `1152Mi`; `mem_request: null` → `256Mi` |
| #31 | Extract `replicaCount` / `autoscaling.minReplicas` from Helm `values.yaml` | No change — `replicaCount` absent in this repo's Helm |
| #34 | Added `_SECRET_DENYLIST_RE` to filter `GF_`, `GRAFANA_`, `SWAGGER_`, `SPRINGDOC_`, `ACTUATOR_` prefixed vars | 3 vars removed: `GF_SECURITY_ADMIN_PASSWORD`, `SWAGGER_URL`, `SWAGGER_CONFIG_URL` |
| #35 | Added `azurerm_cosmosdb_account` module (MongoDB kind) for AKS and Container Apps renderers; `MONGODB_URI` / `SPRING_DATA_MONGODB_URI` marked `infra_managed` | Cosmos DB module now generated; 2 redundant KV secrets eliminated |
| #36 | Emit warning when `len(secrets) > 30`; surface in CLI and profile | ⚠️ "High secret count (39)" warning emitted |

### Infrastructure delta

| Resource | v2 | This run |
|----------|----|----------|
| AKS Cluster | ✓ | ✓ |
| Redis Cache (P1) | ✓ | ✓ |
| Service Bus | ✓ | ✓ |
| Key Vault | ✓ | ✓ |
| **Cosmos DB for MongoDB** | **✗ missing** | **✓ generated** |

---

## Applying YAMLess to pos-elera-sales-compliance

[pos-elera-sales-compliance](https://github.com/krogertechnology/pos-elera-sales-compliance) is a Kroger Technology Java Spring Boot microservice responsible for POS (point-of-sale) sales compliance. It integrates with the ELERA POS platform, Ping Identity for OAuth2/OIDC SSO, Kount for fraud detection, MongoDB for persistence, and RabbitMQ for messaging.

### Command run

```bash
yamless generate https://github.com/krogertechnology/pos-elera-sales-compliance \
  --no-llm \
  --target aks \
  --out-dir ~/yamless/outputs/pos-elera-sales-compliance-aks-2026-11-11
```

### Profile detected

| Field | Detected value | Confidence | Δ vs v2 |
|-------|---------------|------------|---------|
| Runtime | `java` | high | unchanged |
| Runtime version | `25` | high | unchanged |
| Port | `8080` | — | unchanged |
| Shape | `http-service` | high | unchanged |
| Health check path | `/actuator/health` | — | **`/health` → `/actuator/health`** ← fix #28 |
| Memory limit | `1152Mi` | — | **`null` → `1152Mi`** ← fix #29 |
| Memory request | `256Mi` | — | **`null` → `256Mi`** ← fix #29 |
| Database | `mongodb` | high | unchanged |
| Cache | `true` | high | unchanged |
| Queue | `true` | high | unchanged |
| Kafka | `false` | — | unchanged |
| Storage | `false` | — | unchanged |
| Secrets | 39 detected | high | **42 → 39** ← fix #34 |
| Min replicas | `1` | — | unchanged |
| Max replicas | `10` | — | unchanged |
| Ingress | `external: true`, port `8080` | high | unchanged |
| Scale trigger | `http` | high | unchanged |

### Output generated

```
pos-elera-sales-compliance-aks-2026-11-11/
├── profile.json
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── governance.tf
│   └── modules/
│       ├── aks_cluster/
│       ├── aks_workload_identity/
│       ├── keyvault/
│       ├── cosmos/         ← NEW: Cosmos DB for MongoDB
│       ├── redis/
│       ├── servicebus/
│       ├── vnet/
│       └── (postgres, mysql, storage, event_hubs — generated but unused)
└── k8s/
    ├── namespace.yaml
    ├── service-account.yaml
    ├── secret-provider-class.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    └── network-policy.yaml
```

**38 .tf files + 8 K8s manifests written.**

### Cosmos DB module (new in this run)

The generated `module "cosmos"` block in `main.tf`, sized by `golden-profiles/azure-cosmos-db.json` for `production`:

```hcl
module "cosmos" {
  source              = "./modules/cosmos"
  app_name            = local.app_name
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
  keyvault_id         = module.keyvault.id
  keyvault_rbac_ready = module.keyvault
  consistency_level   = "BoundedStaleness"
  throughput_mode     = "autoscale"
  max_autoscale_ru    = 10000
  server_version      = "4.2"
}
```

Golden standards enforced: `kind = "MongoDB"`, `EnableMongo` capability, public network access disabled, MongoDB API v4.2, writes `mongodb-url` to Key Vault — no connection strings in plaintext.

### Deployment manifest (key fields fixed in this run)

```yaml
containers:
  - name: pos-elera-sales-compliance
    ports:
      - containerPort: 8080
    livenessProbe:
      httpGet:
        path: /actuator/health     # was /health in v2
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /actuator/health     # was /health in v2
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 3
    resources:
      requests:
        cpu: 250m
        memory: 256Mi              # was default in v2
      limits:
        cpu: 500m
        memory: 1152Mi             # was default 512Mi in v2
```

### Cost estimate

| Environment | Monthly | Annual | Δ vs v2 |
|-------------|---------|--------|---------|
| Dev | $170 – $245 | $2,040 – $2,940 | +$5–$30 |
| Staging | $392 – $542 | $4,704 – $6,504 | +$50–$150 |
| Production | $1,217 – $1,867 | $14,604 – $22,404 | +$200–$800 |

**Production breakdown:**

| Resource | Cost/month | SKU | Note |
|----------|-----------|-----|------|
| AKS Cluster | $600 | Standard | unchanged |
| **Cosmos DB (MongoDB)** | **$200 – $800** | **Autoscale 10,000 RU** | **new** |
| Redis Cache | $370 | Premium P1 | unchanged |
| Service Bus | $32 – $82 | Standard | unchanged |
| Key Vault | $15 | Premium | unchanged |
| **Total** | **$1,217 – $1,867** | | +$200–$800 vs v2 |

The Cosmos DB range reflects autoscale RU consumption variability — $200/mo at 2,000 RU baseline, up to $800/mo at peak 10,000 RU.

### Secrets detected (39)

Three Grafana/Swagger vars removed by denylist (#34). `MONGODB_URI` and `SPRING_DATA_MONGODB_URI` are `infra_managed` (#35) — `mongodb-url` written by the Cosmos module is authoritative.

| Group | Count | Key examples |
|-------|-------|-------------|
| Ping Identity / OIDC | 13 | `PINGFED_CLIENT_SECRET`, `PING_AUTH_ISSUER_URI`, `PINGFED_DISCOVERY_URL`, `PING_CLIENT_ID` |
| RabbitMQ / AMQP | 3 | `SPRING_RABBITMQ_PASSWORD`, `AMQP_BROKER_PASSWORD`, `MQ_PASSWORD` |
| Redis | 2 | `REDIS_HOST`, `REDIS_KEY` |
| ELERA POS | 3 | `ELERA_BASE_URL`, `ELERA_SERVICE_ACCOUNT_PASSWORD`, `ELERA_REDIRECT_URI` |
| Kount fraud | 2 | `KOUNT_API_KEY`, `KOUNT_BASE_URL` |
| Spring Cloud Config | 1 | `CLOUD_CONFIG_URL` |
| Compliance APIs | 4 | `COMPLIANCE_BASE_URL`, `DB_URI`, `COM_KROGER_POS_COMPLIANCELOGGINGAPI_ENDPOINT` |
| Auth / crypto | 2 | `CIS_RSA_PUBLIC_KEY`, `AUTH_TIMEOUT_CONNECTION` |
| Other endpoints | 9 | `PING_PONG_BASE_URL`, `LOADER_CATALOG_BASE_URL`, `AUTHORIZATION_*`, etc. |

> ⚠️ **Warning:** High secret count (39) detected. Review whether all env vars need to be in Key Vault — consider grouping with a secrets manager pattern or filtering observability vars.

---

## What was missed

| Missing | Root cause | Impact |
|---------|------------|--------|
| AMQP direct reply-to migration risk | No Migration Risk Evaluator — `spring-rabbit` → Service Bus mapping silently drops AMQP 0-9-1 / 1.0 protocol incompatibility | App may fail on `RabbitTemplate.convertSendAndReceive()` or `amq.rabbitmq.reply-to` patterns |
| JMX / management secondary port | Dockerfile analyzer reads only the first `EXPOSE` line | Missing `containerPort`; no NetworkPolicy rule for management port |
| Spring Cloud Config startup dependency | `CLOUD_CONFIG_URL` captured as a secret but not modeled as a startup dependency | Pod will fail to start if config server unreachable; no init container generated |

All three gaps are non-blocking for pod scheduling but represent migration risks. They are driving use cases for the Runtime Enricher and Migration Risk Evaluator in architectural evolution issue [#37](https://github.com/zafar-ahmed-kr/YAMLess/issues/37).

---

## Improvement Roadmap

| Priority | Change | Status |
|----------|--------|--------|
| ~~High~~ | ~~Add MongoDB Spring Data to Java artifact classifier~~ | ✅ Done — #26 |
| ~~High~~ | ~~Add Spring AMQP / RabbitMQ to Java queue classifier~~ | ✅ Done — #27 |
| ~~High~~ | ~~Health check path from actuator / Spring Boot YAML~~ | ✅ Done — #28 |
| ~~High~~ | ~~Memory limits from Helm values / JVM -Xmx inference~~ | ✅ Done — #29 |
| ~~Medium~~ | ~~Min replicas from Helm values~~ | ✅ Done — #31 |
| ~~Medium~~ | ~~Secret filter denylist (Grafana, Swagger, Springdoc)~~ | ✅ Done — #34 |
| ~~High~~ | ~~Cosmos DB for MongoDB module (AKS + Container Apps)~~ | ✅ Done — #35 |
| ~~Low~~ | ~~Warn when secret count exceeds 30~~ | ✅ Done — #36 |
| High | AMQP direct reply-to migration risk surfaced as warning | Open — #30, absorbed into #37 |
| High | JMX / management secondary ports detected and exposed | Open — #32, absorbed into #37 |
| High | Spring Cloud Config startup dependency modeled | Open — #33, absorbed into #37 |
| High | Architectural evolution: Runtime Enricher, Helm Deep Reader, Migration Risk layer | Open — #37 |

---

## Summary

With all fixes through issue #36 applied, YAMLess now produces a substantially more accurate infrastructure workspace for this service. The key gains since v2: health checks now probe `/actuator/health` rather than the Spring Boot default fallback; container memory is sized to the Helm-specified limit of `1152Mi` (preventing OOM kills on the previous `512Mi` default); the Cosmos DB for MongoDB module is generated with production-tier autoscale configuration; and 3 Grafana/Swagger vars are no longer erroneously written to Key Vault.

Three migration risks remain undetected — AMQP protocol incompatibility, secondary ports, and Spring Cloud Config topology — all scoped to the Runtime Enricher and Migration Risk Evaluator in #37.

Production cost increases by $200–$800/month versus v2 (Cosmos DB autoscale), bringing the estimate to **$1,217–$1,867/month**.

---

*Generated by YAMLess — https://github.com/zafar-ahmed-kr/YAMLess*
*Date: 2026-11-11*
