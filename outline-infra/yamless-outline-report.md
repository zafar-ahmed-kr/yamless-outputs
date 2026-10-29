# YAMLess: Generating Azure Infrastructure from Code
### A Case Study — outline/outline

---

## What is YAMLess?

YAMLess is an **Infrastructure from Code (IFC)** tool. Given a code repository, it produces a complete, policy-validated Azure Terraform workspace — with no configuration files, no schema to fill in, and no IaC expertise required from the developer.

The name is a deliberate provocation: you shouldn't have to write YAML (or HCL) to get your app deployed.

---

## The Three-Stage Pipeline

```
Repo on disk
    │
    ▼
┌─────────────────────┐
│  1. Static Analyzer │  Reads Dockerfile, package.json / requirements.txt,
│                     │  .env files, source code — no execution, no API calls.
│                     │  Produces a typed AppProfile with confidence scores.
└──────────┬──────────┘
           │  (if any field is low/medium confidence)
           ▼
┌─────────────────────┐
│  2. LLM Gap-Filler  │  Claude reads up to 10 relevant source files and
│                     │  fills in what static analysis couldn't determine —
│                     │  via structured tool use only (no free-form parsing).
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  3. Renderer        │  Jinja2 root templates + static golden-standard
│                     │  Terraform modules → ready-to-apply workspace.
│                     │  Outputs Container Apps or AKS, selected by --target.
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  4. Validator       │  checkov policy-as-code. 23 checks (Container Apps)
│                     │  / 41 checks (AKS) pass by construction.
└─────────────────────┘
```

The **AppProfile** is the typed contract between stages — a Pydantic model that travels through the pipeline and accumulates confidence scores per field. The LLM only fires when it's needed.

---

## Applying YAMLess to outline/outline

[Outline](https://github.com/outline/outline) is a well-known open-source team wiki: Node.js, Postgres, Redis, S3-compatible storage, OAuth integrations with GitHub, Slack, and Google.

### Command run

```bash
yamless generate https://github.com/outline/outline \
  --no-llm \
  --out-dir ~/outline-infra \
  --validate
```

The `--no-llm` flag was used throughout — static analysis alone produced a high-confidence profile on this repo, with no LLM calls needed.

### Profile detected (fully static, all fields high confidence)

| Field | Detected value |
|-------|---------------|
| Runtime | `node` (from Dockerfile `FROM node:...`) |
| Port | `3000` (from `EXPOSE 3000`) |
| Shape | `http-service` (Koa HTTP framework detected) |
| Database | `postgres` (sequelize + pg in package.json) |
| Storage | `true` (@aws-sdk/client-s3 detected) |
| Cache | `true` (ioredis detected) |
| Ingress | `external: true`, target port `3000` |
| Scale trigger | `http` |
| Secrets | 12 secrets detected from `.env.sample` and source code |

### Output generated

```
outline-infra/
├── main.tf              # 103 lines — wires all modules together
├── variables.tf
├── outputs.tf
├── providers.tf
└── modules/
    ├── managed_identity/   # User-assigned MI with correct RBAC scope
    ├── keyvault/           # Deny-all network ACLs, RBAC auth, secret rotation
    ├── container_app_env/
    ├── container_app/      # Ingress, scaling, KV secret refs
    ├── postgres/           # Flexible server, TLS 1.2, KV connection string
    └── storage/            # Blob storage, RBAC, KV connection string
```

**493 lines of Terraform. Zero lines written by hand.**

### Policy validation

```
✓ 23/23 checks passed
  All policy checks passed.
```

Checks include RBAC-only auth (no access keys), TLS 1.2 minimum everywhere, Key Vault firewall deny-all, no public database endpoints, secret expiration lifecycle, and consistent tagging.

### Sample: detected secrets wired into Key Vault

```hcl
keyvault_secret_names = [
  "database-url",
  "storage-connection-string",
  "aws-cloudfront-private-key",
  "aws-secret-access-key",
  "github-client-secret",
  "github-webhook-secret",
  "redis-url",
  "secret-key",
  "slack-client-secret",
  "slack-verification-token",
  ...
]
```

All 12 secrets detected from `.env.sample` and source code are automatically provisioned as Key Vault secrets and mounted into the Container App — the developer never manually lists them.

---

## AKS Target

The same repo can be rendered for AKS with a single flag change:

```bash
yamless generate /tmp/outline --no-llm --target aks --out-dir ~/outline-aks --validate
```

Output:

```
outline-aks/
├── terraform/          # AKS-specific Terraform
│   ├── main.tf
│   ├── modules/
│   │   ├── vnet/                   # VNet + AKS subnet
│   │   ├── aks_cluster/            # OIDC, Workload Identity, KEDA, CSI driver, ACR
│   │   ├── aks_workload_identity/  # Federated credential + KV Secrets User role
│   │   ├── keyvault/
│   │   ├── postgres/
│   │   └── storage/
└── k8s/                # Kubernetes manifests
    ├── namespace.yaml
    ├── service-account.yaml        # Workload Identity annotation
    ├── secret-provider-class.yaml  # CSI driver — KV secrets as env vars
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── hpa.yaml                    # HPA for HTTP, KEDA ScaledObject for workers
    └── network-policy.yaml         # Default-deny with shape-based allow rules
```

```
✓ 41/41 checks passed
```

The identity model shifts from Container Apps' native Managed Identity to AKS Workload Identity (OIDC + federated credentials), but the developer-facing surface — point at a repo, get infrastructure — stays identical.

---

## Learnings from Testing Against a Real Repo

Testing against outline/outline surfaced three bugs in the static analyzer that would not have been caught with synthetic fixtures alone.

### 1. Shape detection: HTTP services that embed background workers were misclassified

**What happened:** Outline uses `bull` (a background job queue) alongside `koa` (an HTTP framework). The static analyzer's priority order checked for worker packages before HTTP frameworks, so `bull` triggered `shape: background-worker` even though the service is primarily HTTP-facing.

**Root cause:** A service that runs background jobs embedded in its process is still an HTTP service. The worker package hint should only win when there is *no* HTTP framework present.

**Fix:** Moved HTTP framework detection above the worker shape hint. Worker hint is now a fallback, not a priority.

**Lesson for IFC tooling:** Shape detection needs to model the *primary* interface of a service, not just presence of any particular library. Many production services are HTTP APIs that also run embedded workers — the HTTP interface is the one that matters for networking and scaling decisions.

---

### 2. Storage detection was Azure-only

**What happened:** Outline uses `@aws-sdk/client-s3` for file storage. The analyzer's `_STORAGE_PACKAGES` set only contained Azure Blob Storage packages, so `storage: false` was emitted despite clear evidence to the contrary.

**Fix:** Added AWS S3 (`@aws-sdk/client-s3`, `@aws-sdk/lib-storage`, `multer-s3`), GCS (`@google-cloud/storage`), and MinIO packages to the detection set.

**Lesson:** Cloud-agnostic analysis should detect *what a service needs* (object storage) independently of *which cloud* it currently uses. The renderer then maps that need to the target cloud's equivalent. Conflating detection with provider is a classification bug waiting to happen.

---

### 3. Internal vs external ingress heuristic was unreliable

**What happened:** The `_is_external()` function tried to infer whether an HTTP service was public-facing by checking for payment processor secrets (Stripe, Twilio, etc.). Outline has no payment processing, so it was classified as `internal-service` despite being a public wiki.

**Root cause:** Enumerating "public service" signals is a losing strategy — the space of signals is too large and the absence of any particular signal says nothing. Outline uses GitHub OAuth, Slack OAuth, and email — none of which were in the indicator list.

**Fix:** Simplified to always return `external: true` as the default. An HTTP service is assumed public-facing; the LLM gap-filler can correct false positives when it has source file context to confirm internal-only usage patterns.

**Lesson:** For binary classifications where one class is hard to enumerate, pick the safer default and let the LLM handle exceptions. Over-engineering the heuristic introduces confident wrong answers, which are worse than low-confidence right ones — because a `"high"` confidence wrong answer bypasses the LLM gap-filler entirely.

---

## What YAMLess Does Not Automate (Yet)

| Gap | Status |
|-----|--------|
| Redis/cache provisioning | Detected but not rendered — no Azure Cache for Redis module yet |
| Multi-container apps (sidecar pattern) | Not modelled in AppProfile |
| Custom domain / TLS certificate wiring | Placeholder hostname only |
| State backend configuration (remote state) | Left to the operator |
| Environment-specific overrides (dev vs prod) | Single-environment output |

---

## Key Design Decisions

**Golden-standard modules, not LLM-generated Terraform.** The LLM fills in *what* to provision (the profile), but never *how* to provision it. Module files are static and hardcoded. This means security posture cannot regress based on prompt variation — the output is deterministic given a profile.

**Confidence scores drive LLM usage.** The gap-filler is only invoked when static analysis is uncertain. On a well-structured repo like Outline, the LLM isn't called at all. This makes the tool fast, cost-free for clear cases, and targeted in its LLM usage.

**Two compute targets, one profile.** The same `AppProfile` drives both Container Apps and AKS output. The renderer is the only thing that changes. This means future compute targets (e.g. Azure Kubernetes Service with AGIC, or Azure App Service) can be added without touching the analysis pipeline.

---

*Generated by YAMLess — https://github.com/zafar-ahmed-kr/YAMLess*
