# YAMLess — Golden Profiles Merge Report

**Commit:** ed79231  
**Merge Date:** 2026-11-06  
**Branch Merged:** `feature/golden-profiles` → `main`  
**Author:** Sailaja  
**Test Suite:** 187 passed, 0 failed, 1 warning

---

## Summary

The `feature/golden-profiles` branch introduces a comprehensive library of golden configuration profiles for Azure, AWS, and Kubernetes resources, along with governance gate templates, a cost estimator, pod disruption budget manifests, HPA stabilization enhancements, and backend Terraform templates. This merge significantly expands YAMLess's ability to enforce environment-aware infrastructure standards across all four supported renderers (Container Apps, AKS, ECS, EKS).

---

## New Golden Profile JSONs (36 total)

### Azure (15 profiles)

| File | Resource Type |
|------|--------------|
| `azure-postgresql.json` | PostgreSQL Flexible Server |
| `azure-mysql.json` | MySQL Flexible Server |
| `azure-redis.json` | Azure Cache for Redis |
| `azure-storage-account.json` | Storage Account |
| `azure-servicebus.json` | Service Bus Namespace |
| `azure-event-hubs.json` | Event Hubs Namespace |
| `azure-keyvault.json` | Key Vault |
| `azure-container-app.json` | Container Apps |
| `azure-aks-cluster.json` | AKS Cluster |
| `azure-container-registry.json` | Container Registry |
| `azure-cosmos-db.json` | Cosmos DB Account |
| `azure-api-management.json` | API Management |
| `azure-application-gateway.json` | Application Gateway |
| `azure-signalr.json` | SignalR Service |
| `azure-log-analytics-workspace.json` | Log Analytics Workspace |

### AWS (12 profiles)

| File | Resource Type |
|------|--------------|
| `aws-rds.json` | RDS (PostgreSQL/MySQL) |
| `aws-s3.json` | S3 Bucket |
| `aws-sqs.json` | SQS Queue |
| `aws-elasticache-redis.json` | ElastiCache Redis |
| `aws-ecs-fargate.json` | ECS Fargate Service |
| `aws-eks-cluster.json` | EKS Cluster |
| `aws-msk.json` | Managed Streaming for Kafka |
| `aws-ecr.json` | Elastic Container Registry |
| `aws-alb.json` | Application Load Balancer |
| `aws-secrets-manager.json` | Secrets Manager |
| `aws-wafv2.json` | WAF v2 Web ACL |
| `aws-cloudwatch.json` | CloudWatch Alarms/Dashboards |

### Kubernetes (5 profiles)

| File | Resource Type |
|------|--------------|
| `kubernetes-deployment.json` | Deployment |
| `kubernetes-hpa.json` | Horizontal Pod Autoscaler |
| `kubernetes-ingress.json` | Ingress |
| `kubernetes-namespace.json` | Namespace |
| `kubernetes-network-policy.json` | Network Policy |

### Cross-cutting (4 profiles)

| File | Resource Type |
|------|--------------|
| `iam-identity.json` | IAM / Workload Identity |
| `observability-standards.json` | Observability Standards |

---

## New Features

### Governance Gate Templates (`governance.tf.j2`)

Governance Terraform templates were added for all four renderers:

- **Container Apps renderer** — Sentinel/OPA policy stubs enforcing tagging, SKU constraints, and allowed resource types for Azure resources
- **AKS renderer** — Azure Policy assignments at the cluster scope with deny effects for non-compliant workloads
- **ECS renderer** — AWS Config rules and Service Control Policy stubs covering ECS task IAM boundaries
- **EKS renderer** — OPA Gatekeeper constraint templates enforcing namespace labels and pod security standards

Each `governance.tf.j2` includes tagging enforcement blocks ensuring `environment`, `team`, `cost-centre`, and `managed-by` tags are present on all provisioned resources.

### Cost Estimator (`src/yamless/cost_estimator.py`)

A new 628-line module providing pre-render cost estimation based on golden profile selections:

- Looks up unit pricing for Azure and AWS resource SKUs
- Aggregates estimated monthly costs per environment (dev vs production)
- Outputs a cost summary table alongside the rendered Terraform
- Integrates with the CLI via `yamless estimate` subcommand

### PodDisruptionBudget Manifests (`pdb.yaml.j2`)

PDB manifests were added for the AKS and EKS renderers:

- Minimum available replicas derived from the golden profile `min_replicas` field
- Selector labels aligned with the deployment's `app` label
- Rendered alongside the existing deployment and HPA manifests

### HPA Stabilization Windows and Topology Spread Constraints

The existing HPA templates for AKS and EKS were updated to include:

- `scaleDown.stabilizationWindowSeconds` (default 300 s) to prevent flapping
- `scaleUp.stabilizationWindowSeconds` (default 60 s) for faster scale-out
- Topology spread constraints added to deployment manifests ensuring pods are spread across availability zones with `whenUnsatisfiable: DoNotSchedule`

### Backend Terraform (`backend.tf.j2`) and `terraform.tfvars.example.j2`

Remote state configuration templates were added for all four renderers:

- **Azure renderers (Container Apps, AKS):** Azure Blob Storage backend with key derived from app slug and environment
- **AWS renderers (ECS, EKS):** S3 backend with DynamoDB locking table
- `terraform.tfvars.example.j2` provides a documented variable file template for each renderer, reducing onboarding friction

### Expanded Core Modules

| Module | Lines Added | Key Changes |
|--------|-------------|-------------|
| `src/yamless/golden.py` | +177 | Richer profile merging logic; environment overlay support; profile inheritance chains |
| `src/yamless/profile.py` | +77 | Additional profile fields for cost estimator integration; validation helpers |
| `src/yamless/gap_filler.py` | +67 | Gap-filling heuristics for newly added profile keys |
| `src/yamless/cli.py` | +47 | `estimate` subcommand; `--profile-dir` flag for custom profile paths |

---

## Test Results

```
platform darwin -- Python 3.11.9, pytest-9.2.0, pluggy-1.7.0
rootdir: /Users/zafar/yamless
configfile: pyproject.toml

collected 187 items

tests/test_analyzer.py      47 passed
tests/test_arch_drift.py    24 passed
tests/test_env_scanner.py   27 passed
tests/test_gap_filler.py     2 passed
tests/test_golden.py        20 passed   <-- 6 new tests from this merge
tests/test_renderer.py      62 passed
tests/test_validator.py      5 passed

======================== 187 passed, 1 warning in 5.04s ========================
```

**Result: PASS — all 187 tests green.**

The 6 new tests added in `test_golden.py` by this merge cover:

1. Loading a known Azure resource profile for dev environment
2. Loading a known Azure resource profile for production environment
3. Loading a known AWS resource profile
4. Graceful handling of missing resource (returns empty dict)
5. Graceful handling of missing cloud provider (returns empty dict)
6. Graceful handling of both missing (returns empty dict)

Additionally, pre-existing golden tests validate:

- All Azure and AWS profile JSONs are valid (parseable) JSON
- Dev vs production profiles differ on key sizing fields
- Renderer correctly reads SKU and version fields from profiles
- Fallback behaviour when a profile lookup returns empty

---

## Repository Details

| Field | Value |
|-------|-------|
| Commit | ed79231 |
| Merge date | 2026-11-06 |
| Branch | feature/golden-profiles → main |
| Author | Sailaja |
| Golden profiles added | 36 |
| New source lines (approx.) | ~1,100 |
| Tests before merge | 181 |
| Tests after merge | 187 |
| Test result | 187 passed, 0 failed |
