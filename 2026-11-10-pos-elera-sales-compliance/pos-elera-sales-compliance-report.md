# YAMLess Analysis Report
### pos-elera-sales-compliance

**Date:** 2026-11-10
**Repo:** https://github.com/krogertechnology/pos-elera-sales-compliance
**Runs:** Azure Container Apps (`--target container-apps --no-llm`) · Azure AKS (`--target aks --no-llm`)

---

## App Summary

| Field | Value | Confidence |
|-------|-------|------------|
| Name | `pos-elera-sales-compliance` | — |
| Runtime | Java | high |
| Runtime version | 25 | high |
| Shape | `http-service` | high |
| Target port | 8080 | — |
| Dockerfile | Yes | — |
| Health check | `/health` | — |

---

## Detected Dependencies

| Dependency | Detected | Notes |
|------------|----------|-------|
| Cache (Redis) | Yes | Confirmed via `REDIS_HOST` / `REDIS_KEY` secrets |
| Storage | No | — |
| Queue (Service Bus) | No | **Gap:** RabbitMQ/AMQP detected via secrets — see below |
| Kafka (Event Hubs) | No | — |
| Database (SQL) | No | **Gap:** MongoDB detected via secrets — see below |

### Dependency Detection Gaps

The static analyzer correctly detects Redis (cache flag). However, two additional runtime dependencies are present in the secret surface and were **not detected** by the static scanner:

- **MongoDB** — `MONGODB_URI` and `SPRING_DATA_MONGODB_URI` appear in the secrets list. MongoDB is a NoSQL document store; the current dependency scanner only classifies `postgres` and `mysql` SQL databases. As a result, `storage: false` and `database: null` are returned despite an active MongoDB connection being present.

- **RabbitMQ / AMQP** — `SPRING_RABBITMQ_PASSWORD` and `AMQP_BROKER_PASSWORD` indicate a live RabbitMQ or AMQP message broker connection. The scanner's `queue` flag maps to Azure Service Bus; it does not pattern-match RabbitMQ/AMQP package or env-var signals, so `queue: false` is returned.

Both gaps would be caught by the **LLM gap-filler** when run with `ANTHROPIC_API_KEY` set (see Recommendations).

---

## Run 1 — Azure Container Apps

**Command:** `yamless generate pos-elera-sales-compliance --target container-apps --no-llm --validate`

### Generated Infrastructure

**35 Terraform files** written to `outputs/pos-elera-sales-compliance-infra/`

### Cost Estimate

| Resource | Monthly (low) | Monthly (high) | Notes |
|----------|--------------|---------------|-------|
| Container App | $263 | $657 | 1→2 replicas under load |
| Azure Key Vault | $15 | $15 | 43 secrets stored |
| Azure Cache for Redis (P1) | $370 | $370 | P1 SKU for compliance workload |
| **Total** | **$648** | **$1,042** | |
| **Annual** | **$7,776** | **$12,504** | |

The Container App cost range reflects consumption-based scaling (1–2 replicas). Redis P1 ($370/mo) dominates the cost profile. The P1 SKU is selected by the golden profile for production compliance workloads where high availability and in-memory performance are required.

### Checkov Results

**30 / 31 checks passed**

| Result | Count |
|--------|-------|
| Passed | 30 |
| Failed | 1 (MEDIUM) |

**CKV_AZURE_43** — Storage account name does not follow naming rules

- **Severity:** MEDIUM
- **Assessment:** False positive. The analysis profile has `storage: false` — no Storage Account resource was requested or generated. However, Checkov scans all Terraform module files statically, including the `storage` module that ships with yamless as a reusable component. Even though the module is not instantiated in `main.tf`, Checkov evaluates the module's `main.tf` in isolation and flags the placeholder naming variable.
- **Action required:** None. This is a Checkov static-scan artifact, not a configuration defect in the generated workspace.

---

## Run 2 — Azure AKS

**Command:** `yamless generate pos-elera-sales-compliance --target aks --no-llm --validate`

### Generated Infrastructure

**35 Terraform files** + **8 Kubernetes manifests (.yaml)** written to `outputs/pos-elera-sales-compliance-aks-infra/`

Kubernetes manifests include: `namespace.yaml`, `service-account.yaml`, `secret-provider-class.yaml`, `deployment.yaml`, `service.yaml`, `ingress.yaml`, `hpa.yaml`, `pdb.yaml`

### Cost Estimate

| Resource | Monthly | Annual | Notes |
|----------|---------|--------|-------|
| AKS Cluster | $600 | $7,200 | Standard tier, 2-node system pool |
| Azure Cache for Redis (P1) | $370 | $4,440 | P1 SKU for compliance workload |
| Azure Key Vault | $15 | $180 | 43 secrets stored |
| **Total** | **$985** | **$11,820** | Fixed cost — node pool always running |

AKS cost is fixed regardless of replica count, since the node pool runs continuously. Appropriate for workloads with steady, predictable traffic.

### Checkov Results

**48 / 49 checks passed**

| Result | Count |
|--------|-------|
| Passed | 48 |
| Failed | 1 (MEDIUM) |

**CKV_AZURE_43** — Storage account name does not follow naming rules

- **Severity:** MEDIUM
- **Assessment:** Same false positive as the Container Apps run — Checkov scans the uninstantiated `storage` module in the yamless module library. No action required.

---

## Run Comparison

| | Container Apps | AKS |
|--|--|--|
| Target | `--target container-apps` | `--target aks` |
| Cost | $648–$1,042/mo variable | $985/mo fixed |
| Annual | $7,776–$12,504 | $11,820 |
| Terraform files | 35 .tf | 35 .tf |
| K8s manifests | None | 8 .yaml |
| Checkov passed | 30/31 | 48/49 |
| Checkov failure | CKV_AZURE_43 (false positive) | CKV_AZURE_43 (false positive) |
| Scaling model | Consumption-based (HTTP trigger) | Node pool + HPA |
| Control plane | Managed (no K8s exposure) | Full AKS control plane |

### Target Recommendation

**AKS ($985/mo fixed) is preferred** for `pos-elera-sales-compliance`. POS compliance services typically run at steady load with predictable traffic patterns — AKS fixed pricing is more cost-predictable than the Container Apps variable range ($648–$1,042/mo). AKS also provides a full Kubernetes control plane, enabling fine-grained network policies, pod security standards, and workload identity integration appropriate for a compliance workload. The 8 K8s manifests generated by the AKS run enforce topology spread constraints, pod disruption budgets, and HPA stabilization windows out of the box.

---

## Secrets Breakdown

**Total secrets detected: 43**

### Ping Identity / OIDC (17 secrets)

| Secret | Purpose |
|--------|---------|
| `AUTHORIZATION_OAUTH2_REDIRECT_URI` | OAuth2 redirect callback |
| `AUTHORIZATION_PING_BASE_ENDPOINT` | PingFederate base URL |
| `AUTHORIZATION_PING_PASSWORD` | PingFederate service account |
| `PINGFED_CLIENT_SECRET` | PingFederate client secret |
| `PINGFED_DISCOVERY_URL` | OIDC discovery endpoint |
| `PING_AUTH_ISSUER_URI` | PingOne JWT issuer |
| `PING_AUTH_JWK_SET_URI` | PingOne JWK public keys |
| `PING_BASE_ENDPOINT` | Ping Identity base URL |
| `PING_CLIENT_ID` | Ping OAuth2 client ID |
| `PING_FED_AUTH_ISSUER_URI` | PingFederate JWT issuer |
| `PING_FED_AUTH_JWT_SET_URI` | PingFederate JWK public keys |
| `PING_PASSWORD` | Ping service account password |
| `PING_PONG_BASE_URL` | Ping connectivity check endpoint |
| `PING_USERNAME` | Ping service account username |
| `SPRING_SECURITY_OAUTH2_PING_FED_JWT_ISSUER_URI` | Spring Security PingFed issuer |
| `SPRING_SECURITY_OAUTH2_PING_FED_JWT_JWK_SET_URI` | Spring Security PingFed JWK |
| `SPRING_SECURITY_OAUTH2_PING_ONE_JWT_ISSUER_URI` | Spring Security PingOne issuer |
| `SPRING_SECURITY_OAUTH2_PING_ONE_JWT_JWK_SET_URI` | Spring Security PingOne JWK |

This service integrates with both **PingFederate** (enterprise on-premises SSO) and **PingOne** (cloud SSO) simultaneously, suggesting a dual-IdP OIDC setup during a migration or for different client types.

### MongoDB (2 secrets)

| Secret | Purpose |
|--------|---------|
| `MONGODB_URI` | MongoDB connection string |
| `SPRING_DATA_MONGODB_URI` | Spring Data MongoDB connection (may be same host) |

### RabbitMQ / AMQP (3 secrets)

| Secret | Purpose |
|--------|---------|
| `AMQP_BROKER_PASSWORD` | AMQP broker authentication |
| `MQ_PASSWORD` | Message queue password (likely same broker) |
| `SPRING_RABBITMQ_PASSWORD` | Spring AMQP RabbitMQ password |

### Kount Fraud Detection (2 secrets)

| Secret | Purpose |
|--------|---------|
| `KOUNT_API_KEY` | Kount fraud/risk API key |
| `KOUNT_BASE_URL` | Kount API endpoint |

### ELERA POS Platform (3 secrets)

| Secret | Purpose |
|--------|---------|
| `ELERA_BASE_URL` | ELERA POS platform base URL |
| `ELERA_REDIRECT_URI` | ELERA OAuth/SSO redirect |
| `ELERA_SERVICE_ACCOUNT_PASSWORD` | ELERA service account credential |

### Redis Cache (2 secrets)

| Secret | Purpose |
|--------|---------|
| `REDIS_HOST` | Redis host / connection string |
| `REDIS_KEY` | Redis access key / password |

### Other External Services (remaining secrets)

| Secret | Purpose |
|--------|---------|
| `AUTH_TIMEOUT_CONNECTION` | Auth service connection timeout |
| `AUTH_TIMEOUT_READ` | Auth service read timeout |
| `CIS_RSA_PUBLIC_KEY` | CIS RSA public key (token verification) |
| `CLOUD_CONFIG_URL` | Spring Cloud Config server URL |
| `COMPLIANCE_BASE_URL` | Compliance service base URL |
| `COM_KROGER_POS_COMPLIANCELOGGINGAPI_ENDPOINT` | Compliance logging API endpoint |
| `DB_URI` | Generic database URI |
| `EXTERNAL_SERVICES_LOADER_CATALOG_BASE_URL` | External loader catalog URL |
| `GF_SECURITY_ADMIN_PASSWORD` | Grafana admin password |
| `LOADER_CATALOG_BASE_URL` | Loader catalog service URL |
| `SWAGGER_CONFIG_URL` | Swagger UI config URL |
| `SWAGGER_URL` | Swagger API spec URL |

---

## Analyst Notes and Recommendations

### 1. Re-run with `--llm` to Add MongoDB + RabbitMQ Modules

The static analyzer returned `confidence: high` for runtime, secrets, and shape. However, two significant runtime dependencies — MongoDB and RabbitMQ — were **not detected** because the static scanner does not pattern-match NoSQL databases or AMQP brokers. Running the full pipeline with `ANTHROPIC_API_KEY` set will invoke the LLM gap-filler, which reads source files and infers these dependencies from context.

```bash
yamless generate /path/to/pos-elera-sales-compliance --out-dir ./output --validate
```

Adding MongoDB and RabbitMQ would materially change the generated infrastructure (additional Azure Cosmos DB and Service Bus modules), and would increase estimated cost.

### 2. Add MongoDB Module to Generated Terraform

Once the gap-filler detects MongoDB, the renderer should emit an **Azure Cosmos DB for MongoDB** module. Cosmos DB provides MongoDB wire-protocol compatibility with Azure-native management, private endpoints, and automatic indexing.

Expected additional cost: ~$25–$100/mo (serverless tier) or ~$600+/mo (provisioned throughput).

### 3. Add RabbitMQ / AMQP Module

RabbitMQ is not a native Azure service. Options for the generated Terraform:

- **Azure Service Bus** — if the team can migrate AMQP clients to AMQP 1.0 (Service Bus is AMQP 1.0 compatible; RabbitMQ is AMQP 0-9-1). This is the preferred cloud-native path and is already supported by the yamless `servicebus` module.
- **Self-hosted RabbitMQ on AKS** — if AMQP 0-9-1 is required. Outside yamless' current scope.

Consider opening a backlog item to add RabbitMQ/AMQP detection in `analyzer/dependencies.py` (pattern-match `spring-rabbit`, `amqp`, `amqplib` package names and `RABBITMQ`/`AMQP` env-var prefixes).

### 4. PingFederate + PingOne Dual-IdP Pattern

The 17 Ping-related secrets indicate simultaneous integration with both PingFederate (enterprise on-premises SSO) and PingOne (cloud SSO). This is a recognized migration pattern. All Ping secrets are correctly identified and will be stored in Azure Key Vault. No action required on the infrastructure side, but the security team should review whether duplicate issuer URIs (`PING_AUTH_ISSUER_URI` vs `PING_FED_AUTH_ISSUER_URI`) represent intentional dual-validation or a configuration redundancy.

### 5. Kount Fraud API

`KOUNT_API_KEY` and `KOUNT_BASE_URL` are correctly detected as secrets and will be stored in Key Vault. Kount is a third-party fraud detection platform used in POS and payment compliance flows. No additional infrastructure is needed.

### 6. High Secret Count (43)

43 secrets is on the high end for a single service and reflects the complexity of this microservice's external integrations: dual IdP (PingFed + PingOne), MongoDB, RabbitMQ, Redis, Kount, ELERA POS, compliance logging, and Spring Cloud Config. All 43 will be stored in Azure Key Vault under the generated workspace. Consider auditing for duplicates — `MONGODB_URI` and `SPRING_DATA_MONGODB_URI` likely point to the same host, and several `PING_*` / `PINGFED_*` variables may be redundant config aliases.

---

## Summary

`pos-elera-sales-compliance` is a production Java 25 POS compliance microservice with a rich integration surface: dual Ping Identity SSO, MongoDB, RabbitMQ/AMQP, Redis cache, Kount fraud detection, and the ELERA POS platform. Two runs were executed against different targets.

**Static analysis coverage (both runs):**
- Runtime, shape, secrets: high confidence — correct
- Database (MongoDB): missed — LLM gap-filler required
- Queue (RabbitMQ): missed — LLM gap-filler required

**Container Apps run:** 35 .tf files, $648–$1,042/mo, 30/31 Checkov checks pass.
**AKS run:** 35 .tf + 8 .yaml files, $985/mo fixed, 48/49 Checkov checks pass.

The single MEDIUM Checkov failure (CKV_AZURE_43) is a false positive caused by Checkov scanning an uninstantiated storage module — present in both runs.

**Recommended target:** AKS for predictable fixed cost and full Kubernetes control plane.
**Recommended next step:** Run with `--no-llm` removed (LLM gap-filler enabled) to produce MongoDB (Cosmos DB) and RabbitMQ (Service Bus) modules in the generated Terraform.

---

*Generated by YAMLess — https://github.com/zafar-ahmed-kr/YAMLess*
