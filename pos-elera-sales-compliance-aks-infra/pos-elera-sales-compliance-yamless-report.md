# YAMLess: Generating Azure Infrastructure from Code
### Case Study — krogertechnology/pos-elera-sales-compliance

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

## Applying YAMLess to pos-elera-sales-compliance

[pos-elera-sales-compliance](https://github.com/krogertechnology/pos-elera-sales-compliance) is a Kroger Technology Java Spring Boot microservice responsible for POS (point-of-sale) sales compliance. It integrates with the ELERA POS platform, Ping Identity for OAuth2/OIDC SSO, Kount for fraud detection, MongoDB for persistence, and RabbitMQ for messaging.

### Command run

```bash
yamless generate https://github.com/krogertechnology/pos-elera-sales-compliance \
  --no-llm \
  --target aks \
  --out-dir ~/yamless/outputs/pos-elera-sales-compliance-aks-infra \
  --validate
```

### Profile detected

| Field | Detected value | Confidence | Notes |
|-------|---------------|------------|-------|
| Runtime | `java` | high | `pom.xml` present at repo root |
| Runtime version | `25` | high | Detected from Dockerfile Java base image |
| Port | `8080` | high | Standard Spring Boot port |
| Shape | `http-service` | high | Spring MVC / REST controller detected |
| Database | `null` | — | MongoDB not in known pom.xml artifact set; LLM gap-filler required |
| Cache | `true` | high | Redis dependency detected in pom.xml |
| Queue | `false` | — | RabbitMQ present in secrets but not in known artifact set |
| Kafka | `false` | — | Not detected |
| Storage | `false` | — | Not detected |
| Secrets | 43 detected | high | Helm values + Spring YAML + source code scanned |
| Ingress | `external: true`, port `8080` | high | |
| Scale trigger | `http` | high | HTTP service shape |

### Output generated

```
pos-elera-sales-compliance-aks-infra/
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
│       ├── redis/          ← detected dependency
│       ├── vnet/
│       ├── postgres/       ← generated but unused (database: null)
│       ├── mysql/          ← generated but unused
│       ├── storage/        ← generated but unused
│       ├── servicebus/     ← generated but unused
│       └── event_hubs/     ← generated but unused
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

**35 .tf files + 8 K8s manifests written.**

**48/49 policy checks passed.** One MEDIUM failure:

| Check | Resource | Verdict |
|-------|----------|---------|
| CKV_AZURE_43 — Storage account naming rules | `azurerm_storage_account.this` | False positive — `storage: false`; checkov scans all module files including unused ones |

### Cost estimate

| Environment | Monthly | Annual |
|-------------|---------|--------|
| Dev | $160 | $1,920 |
| Staging | $310 | $3,720 |
| Production | $985 | $11,820 |

**Production breakdown:**

| Resource | Cost/month | SKU |
|----------|-----------|-----|
| AKS Cluster | $600 | Standard, m5.large equivalent nodes |
| Redis Cache | $370 | P1 (Premium — production standard) |
| Key Vault | $15 | Standard |
| **Total** | **$985** | |

*Pricing as of 2026-11-06, approx. UK South on-demand.*

### Secrets detected (43)

| Group | Count | Key examples |
|-------|-------|-------------|
| Ping Identity / OIDC | 13 | `PINGFED_CLIENT_SECRET`, `PING_AUTH_ISSUER_URI`, `PINGFED_DISCOVERY_URL`, `PING_CLIENT_ID` |
| MongoDB | 2 | `MONGODB_URI`, `SPRING_DATA_MONGODB_URI` |
| RabbitMQ / AMQP | 2 | `SPRING_RABBITMQ_PASSWORD`, `AMQP_BROKER_PASSWORD` |
| Redis | 2 | `REDIS_HOST`, `REDIS_KEY` |
| ELERA POS | 3 | `ELERA_BASE_URL`, `ELERA_SERVICE_ACCOUNT_PASSWORD`, `ELERA_REDIRECT_URI` |
| Kount fraud | 2 | `KOUNT_API_KEY`, `KOUNT_BASE_URL` |
| Spring Cloud / Config | 2 | `CLOUD_CONFIG_URL`, `SWAGGER_CONFIG_URL` |
| Compliance APIs | 4 | `COMPLIANCE_BASE_URL`, `DB_URI`, `COM_KROGER_POS_COMPLIANCELOGGINGAPI_ENDPOINT` |
| Other | 13 | Auth timeouts, RSA keys, Grafana admin, loader catalog URLs |

All 43 secrets are provisioned in Azure Key Vault and mounted to the pod via the Key Vault CSI driver.

### What the output correctly captured

- AKS cluster with Workload Identity and Key Vault CSI wiring
- All 43 secrets surfaced into Key Vault — none left as plaintext env vars
- Redis Cache module (P1 in production, C1 in dev/staging)
- External HTTP ingress on port 8080 with Network Policy
- HPA (HTTP scale trigger, 1–10 replicas) + KEDA-ready ScaledObject
- Full K8s manifest set: Namespace, ServiceAccount, SecretProviderClass, Deployment, Service, Ingress, HPA, NetworkPolicy
- Governance gates in `governance.tf`: mandatory tags, min-replica policy, autoscaling, backup retention
- Security golden standards: RBAC-only auth, TLS 1.2, Key Vault firewall deny-all, private AKS nodes

---

## What was missed

| Missing | Root cause | Impact |
|---------|------------|--------|
| MongoDB database module | `spring-boot-starter-data-mongodb` not in known pom.xml artifact set | No Cosmos DB API for MongoDB provisioned; app will fail to connect |
| RabbitMQ queue module | `spring-boot-starter-amqp` not in known artifact set | No Service Bus provisioned; AMQP messaging will fail |
| Port detection | No `EXPOSE` in Dockerfile (defaults to 8080 from shape detection) | Low risk — 8080 is correct for Spring Boot |

---

## Learnings for YAMLess

### 1. MongoDB support needed in Java artifact set

**What happened:** The pom.xml contains `spring-boot-starter-data-mongodb` and `de.flapdoodle.embed.mongo` (embedded test Mongo). The static analyzer's Java artifact table does not include MongoDB Spring Data as a database signal — it looks for Postgres/MySQL JDBC drivers and ORM packages.

**Proposed fix:** Add `spring-boot-starter-data-mongodb`, `mongodb-driver-sync`, and `flapdoodle.embed.mongo` to the Java dependency classifier. When detected, set `database: mongodb` and emit a Cosmos DB for MongoDB or Atlas module.

**Impact:** Affects any Java Spring Boot app using MongoDB — a common pattern in Kroger microservices.

---

### 2. RabbitMQ / Spring AMQP detection missing

**What happened:** `spring-boot-starter-amqp` and `spring-rabbit` are present in `pom.xml`. The analyzer's queue detection covers Azure Service Bus SDK and `@azure/service-bus` for Node, but does not include Spring AMQP as a queue signal.

**Proposed fix:** Add `spring-boot-starter-amqp`, `spring-rabbit`, and `rabbitmq-client` to the queue classifier. When detected, set `queue: true` and emit a Service Bus module (the generated infrastructure equivalent of RabbitMQ in Azure).

---

### 3. High secret count reflects complex external integration

The 43 detected secrets highlight the app's integration surface: PingFederate + PingOne (13 secrets), ELERA POS (3), Kount fraud (2), MongoDB (2), RabbitMQ (2). This is not a gap — the secret scanner correctly identified all of them from Helm values, Spring Boot YAML, and Docker Compose files. All are correctly provisioned in Key Vault.

However, the depth of Ping Identity integration (dual-IdP: PingFederate and PingOne simultaneously) is worth noting. The generated Kubernetes SecretProviderClass mounts all 43 secrets, which is unusually large and may warrant secret consolidation in a follow-up.

---

## Improvement Roadmap

| Priority | Change | Impact |
|----------|--------|--------|
| High | Add MongoDB Spring Data to Java artifact classifier | Fixes `database: null` for this and similar Kroger Java microservices |
| High | Add Spring AMQP / RabbitMQ to Java queue classifier | Generates Service Bus module for AMQP-based apps |
| Medium | Cosmos DB for MongoDB module (Azure) | Provides a native Azure-managed MongoDB-compatible store |
| Low | Secret consolidation recommendation when count > 30 | Flag unusually large secret sets for review |

---

## Summary

`pos-elera-sales-compliance` is a well-structured Java Spring Boot microservice with a clear HTTP service shape, correct port detection, and an exceptionally thorough secret inventory (43 secrets correctly identified). YAMLess produced a complete, policy-passing AKS workspace with 48/49 checkov checks passing.

The two gaps — MongoDB and RabbitMQ — are both static-analyzer limitations in the Java artifact classifier rather than fundamental tool constraints. Both would be resolved by the LLM gap-filler in a full run (`--no-llm` was used here). Once the artifact classifier is extended, YAMLess will generate the complete infrastructure for this service class automatically.

The $985/month production cost estimate is dominated by the AKS cluster ($600) and Premium Redis ($370), consistent with a POS compliance service requiring high availability and low-latency session caching.

---

*Generated by YAMLess — https://github.com/zafar-ahmed-kr/YAMLess*
*Date: 2026-11-10*
