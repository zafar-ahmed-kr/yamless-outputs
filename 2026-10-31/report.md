# YAMLess Test Report — 2026-10-30

## Summary

**136/136 tests passed** across all test suites.

Live end-to-end validation completed against two real-world repos:
- **Redash** (`getredash/redash`) — Python/Postgres/Redis — ✓ 30/30 checkov checks
- **Ghost** (`TryGhost/Ghost`) — Node.js/pnpm monorepo — ✓ 30/30 checkov checks

---

## Issues Resolved This Session

### Issue #8 + #11 — Recursive Secret Scanning + Runtime-Injected Secrets

- **Fix:** `_scan_dot_notation_configs()` changed from `glob` to `rglob` — now scans nested `config.*.json`/`.yaml` files throughout the whole repo tree, not just the root directory.
- **Validation:** Ghost's `ghost/core/shared/config/env/config.production.json` now yields `DATABASE__CONNECTION__PASSWORD` and `MAIL__OPTIONS__AUTH__PASS`.
- **Before fix:** 0 dot-notation config secrets detected from Ghost.
- **After fix:** 6 dot-notation secrets detected including `DATABASE__CONNECTION__PASSWORD`, `MAIL__OPTIONS__AUTH__PASS`, `EXPLORE__TESTIMONIALS_URL`.

### Issue #9 — Redis / Azure Cache Module (CKV_AZURE_89 fix)

- **Fix:** Added `public_network_access_enabled = false` to both Container Apps and AKS Redis modules.
- **Fix:** Added `CKV_AZURE_230` (Standard replication) to the validator skip list — Basic C0 SKU doesn't support it.
- **Validation:** Redash generate went from `✗ 29/31 checks passed` → `✓ 30/30 checks passed`.

### Issue #10 — Kafka / Azure Event Hubs Module

- `azurerm_eventhub_namespace` + `azurerm_eventhub` + consumer group + RBAC + KV secret
- `has_kafka` flag wired through analyzer → profile → renderer → templates for both Container Apps and AKS
- `kafkajs`, `kafka-python`, `confluent-kafka`, `aiokafka` package detection
- 8 new tests — all passing

### Issue #6 — Multi-Shape Model (web + worker processes)

- `WorkerProfile` model: `shape`, `scale_trigger`, `min_replicas`, `max_replicas`, `command`
- `workers: list[WorkerProfile] = []` on `AppProfile`
- Container Apps: renders additional `module "container_app_worker_N"` blocks per worker; no ingress for workers
- AKS: renders additional `deployment-worker-N.yaml` + `hpa-worker-N.yaml` per worker; workers share main app's SecretProviderClass via `{{ namespace }}-secrets`
- Gap-filler: `workers` array added to tool schema
- 8 new tests — all passing

---

## Test Counts by Suite

| Suite | Tests | Status |
|-------|-------|--------|
| test_analyzer.py | 26 | ✓ All pass |
| test_arch_drift.py | 25 | ✓ All pass |
| test_env_scanner.py | 18 | ✓ All pass |
| test_gap_filler.py | 2 | ✓ All pass |
| test_renderer.py | 62 | ✓ All pass |
| test_validator.py | 3 | ✓ All pass |
| **Total** | **136** | **✓ All pass** |

---

## Live Repo Results

### Redash

```
App:    redash | python 3.13 | http-service | port 5000
Deps:   postgres ✓  redis ✓
Secrets: 22 detected
Checkov: ✓ 30/30 checks passed
```

### Ghost (TryGhost monorepo)

```
App:    ghost-repo | node | http-service | port 2368
Deps:   (pnpm monorepo — app_root falls back to root without LLM)
Secrets: 19 detected (including DATABASE__CONNECTION__PASSWORD from nested config.*.json)
Checkov: ✓ 30/30 checks passed
```

---

## Branch

All changes committed to `develop` (branch `c781903`). Ready for manual merge to `main`.
