# YAMLess Test Report — 2026-10-31 (issue #15)

## Summary

**147/147 tests passed** across all test suites.

---

## Issue #15 — .NET / C# Runtime Support

### Problem
YAMLess returned `runtime: unknown`, `shape: unknown`, no dependencies, and `secrets: []` on .NET repos. Two root causes:
1. No NuGet / `.csproj` parser
2. `_find_dockerfile` only checked the repo root — .NET solutions conventionally put `Dockerfile` inside the API project subdirectory

### Changes

| File | Change |
|------|--------|
| `profile.py` | `Runtime.DOTNET = "dotnet"` |
| `dockerfile.py` | `dotnet/aspnet\|runtime\|sdk` image patterns; `_find_dockerfile` searches one level deep, prefers `api`/`web` dirs |
| `dependencies.py` | NuGet package maps (Npgsql, StackExchange.Redis, AWSSDK.S3/SQS, Confluent.Kafka, etc.); `get_dotnet_package_names()` rglobs `*.csproj` skipping test projects; `_parse_dotnet()` |
| `env_scanner.py` | `_scan_appsettings()` — flattens secret leaf keys + `${VAR}` placeholders from `appsettings*.json` |
| `runner.py` | `*.sln` / `*/*.csproj` detection in `_infer_runtime_from_files`; dotnet branch in `all_dep_names` dispatch |
| `tests/fixtures/dotnet-api/` | Multi-stage `Api/Dockerfile` (aspnet:8.0), `Api/Api.csproj`, `Api/appsettings.json` |

### Detection coverage

**Databases:** Npgsql, Npgsql.EntityFrameworkCore.PostgreSQL → postgres; MySqlConnector, Pomelo.EntityFrameworkCore.MySql → mysql; Microsoft.Data.SqlClient → sqlserver; Microsoft.Azure.Cosmos → cosmos

**Cache:** StackExchange.Redis, Microsoft.Extensions.Caching.StackExchangeRedis, NRedisStack

**Storage:** Azure.Storage.Blobs, AWSSDK.S3, Google.Cloud.Storage.V1

**Queue:** Azure.Messaging.ServiceBus, AWSSDK.SQS, RabbitMQ.Client, MassTransit

**Kafka:** Confluent.Kafka, MassTransit.Kafka

**HTTP shape:** Swashbuckle.AspNetCore, Microsoft.AspNetCore.OpenApi, Carter, FastEndpoints, NSwag.AspNetCore

### New Tests (11)

- `test_dotnet_runtime_detected_from_dockerfile` — aspnet:8.0 image → DOTNET, version 8.0
- `test_dotnet_nested_dockerfile_found` — Api/Dockerfile resolved from fixture
- `test_dotnet_nuget_packages_parsed` — all 5 packages from Api.csproj
- `test_dotnet_full_profile` — runtime, version, port, shape all correct
- `test_dotnet_database_detected` — Npgsql.EntityFrameworkCore.PostgreSQL → postgres
- `test_dotnet_cache_detected` — StackExchange.Redis → cache=True
- `test_dotnet_storage_detected` — AWSSDK.S3 → storage=True
- `test_dotnet_queue_detected` — AWSSDK.SQS → queue=True
- `test_dotnet_appsettings_secrets_scanned` — JWT_SECRET, REDIS_URL from appsettings.json
- `test_dotnet_inferred_from_csproj_without_dockerfile` — runtime inferred from Src/MyApp.csproj
- `test_dotnet_test_projects_excluded` — App.Tests.csproj ignored

---

## Test Counts by Suite

| Suite | Tests | Status |
|-------|-------|--------|
| test_analyzer.py | 37 | ✓ All pass |
| test_arch_drift.py | 25 | ✓ All pass |
| test_env_scanner.py | 18 | ✓ All pass |
| test_gap_filler.py | 2 | ✓ All pass |
| test_renderer.py | 62 | ✓ All pass |
| test_validator.py | 3 | ✓ All pass |
| **Total** | **147** | **✓ All pass** |

---

## Branch

Committed to `develop`, merged to `main` (commit `77258f3`).
