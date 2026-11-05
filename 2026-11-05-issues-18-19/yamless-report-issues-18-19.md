# YAMLess — Implementation & Test Report
## Issues #18 and #19

**Date:** 2026-11-05
**Commit:** `9dc0061`
**Branch:** `develop`
**Test suite:** 181 passed, 0 failed

---

## Summary

Two issues were resolved in commit `9dc0061` on the `develop` branch of the YAMLess project. The changes extend the analyzer's app-name normalization logic and add source-code scanning support for C#, Java, and Kotlin environments.

---

## Issue #18 — App Name Slugification

### Problem
App names derived from repository names could contain characters that are invalid in Azure resource names (dots, underscores, uppercase letters, leading/trailing dashes). Storage account names and Key Vault names have especially strict length and character constraints.

### Implementation

**`src/yamless/analyzer/runner.py`** — `_slugify()` function added:
- Lowercases the input string
- Replaces runs of non-alphanumeric characters with a single `-`
- Strips leading and trailing dashes
- Truncates to 40 characters

**Storage module** (`src/yamless/renderer/container_apps/modules/storage/main.tf` and AKS equivalent):
- Strips both `-` and `.` before applying the 24-character substring truncation

**Key Vault module** (`src/yamless/renderer/container_apps/modules/keyvault/main.tf` and AKS equivalent):
- Uses `trimsuffix(trimprefix(...))` to prevent trailing or leading dashes after truncation

### New Tests (Issue #18)

| Test | File | Description |
|------|------|-------------|
| `test_slugify_plain_name` | `tests/test_analyzer.py` | Simple lowercase name passes through unchanged |
| `test_slugify_lowercases` | `tests/test_analyzer.py` | Uppercase letters are lowercased |
| `test_slugify_dots_replaced_with_dashes` | `tests/test_analyzer.py` | Dots are converted to dashes |
| `test_slugify_underscores_replaced` | `tests/test_analyzer.py` | Underscores are converted to dashes |
| `test_slugify_leading_trailing_dashes_stripped` | `tests/test_analyzer.py` | Leading/trailing dashes removed |
| `test_slugify_multiple_separators_collapsed` | `tests/test_analyzer.py` | Consecutive separators collapsed to single dash |
| `test_slugify_truncates_to_40_chars` | `tests/test_analyzer.py` | Output truncated at 40 characters |
| `test_slugify_dotted_repo_name` | `tests/test_analyzer.py` | Real-world dotted repo name slugified correctly |

---

## Issue #19 — C# and Java / Kotlin Environment Variable Scanning

### Problem
The environment variable scanner only handled Python, Node.js, and config-file patterns. Applications written in C# or Java/Kotlin that read secrets via `Environment.GetEnvironmentVariable`, `IConfiguration`, or Spring `@Value` annotations were not discovered.

### Implementation

**`src/yamless/analyzer/env_scanner.py`** — `_scan_source_files()` extended to cover `.cs`, `.java`, and `.kt` files:

| Pattern | Language | Emitted Key |
|---------|----------|-------------|
| `Environment.GetEnvironmentVariable("KEY")` | C# | `KEY` |
| `System.getenv("KEY")` | C# / Java | `KEY` |
| `configuration["Section:Key"]` | C# (IConfiguration) | `SECTION__KEY` (double-underscore) |
| `GetConnectionString("Name")` | C# | `NAME` (uppercased) |
| `@Value("${prop.name}")` | Java / Kotlin (Spring) | `PROP_NAME` (dots → underscores, uppercased) |

Generated C# files (`*.Designer.cs`, `*.g.cs`) are automatically skipped.

**New fixture:** `tests/fixtures/dotnet-api/Api/Program.cs` — sample C# program exercising all three IConfiguration patterns.

### New Tests (Issue #19)

| Test | File | Description |
|------|------|-------------|
| `test_cs_environment_get_env_variable` | `tests/test_env_scanner.py` | `Environment.GetEnvironmentVariable` key extracted |
| `test_cs_configuration_indexer` | `tests/test_env_scanner.py` | `configuration["Section:Key"]` → `SECTION__KEY` |
| `test_cs_get_connection_string` | `tests/test_env_scanner.py` | `GetConnectionString("Name")` → `NAME` |
| `test_cs_generated_file_skipped` | `tests/test_env_scanner.py` | `*.Designer.cs` files are ignored |
| `test_java_system_getenv` | `tests/test_env_scanner.py` | `System.getenv("KEY")` extracted |
| `test_java_spring_value_annotation` | `tests/test_env_scanner.py` | `@Value("${prop.name}")` → `PROP_NAME` |
| `test_java_spring_value_with_default` | `tests/test_env_scanner.py` | `@Value("${prop.name:default}")` strips default |
| `test_kotlin_spring_value_annotation` | `tests/test_env_scanner.py` | Same Spring `@Value` pattern in `.kt` files |
| `test_dotnet_fixture_program_cs_configuration_indexer` | `tests/test_analyzer.py` | End-to-end: config indexer key in full profile |
| `test_dotnet_fixture_program_cs_stripe_key` | `tests/test_analyzer.py` | End-to-end: Stripe key detected via GetEnvironmentVariable |
| `test_dotnet_fixture_program_cs_sendgrid_key` | `tests/test_analyzer.py` | End-to-end: SendGrid key detected via GetConnectionString |

---

## Full Test Results

**Total: 181 passed, 0 failed, 1 warning (pytest deprecation notice — no action required)**

| Test File | Tests | Result |
|-----------|-------|--------|
| `tests/test_analyzer.py` | 47 | PASSED |
| `tests/test_arch_drift.py` | 26 | PASSED |
| `tests/test_env_scanner.py` | 36 | PASSED |
| `tests/test_gap_filler.py` | 2 | PASSED |
| `tests/test_golden.py` | 13 | PASSED |
| `tests/test_renderer.py` | 54 | PASSED |
| `tests/test_validator.py` | 3 | PASSED |
| **Total** | **181** | **ALL PASSED** |

---

## Files Changed

| File | Change |
|------|--------|
| `src/yamless/analyzer/runner.py` | Added `_slugify()` function |
| `src/yamless/analyzer/env_scanner.py` | Extended `_scan_source_files()` for C# / Java / Kotlin |
| `src/yamless/renderer/container_apps/modules/storage/main.tf` | Strip `-` and `.` before 24-char truncation |
| `src/yamless/renderer/container_apps/modules/keyvault/main.tf` | Use `trimsuffix`/`trimprefix` after truncation |
| `src/yamless/renderer/aks/modules/storage/main.tf` | Same storage fix for AKS target |
| `src/yamless/renderer/aks/modules/keyvault/main.tf` | Same Key Vault fix for AKS target |
| `tests/test_analyzer.py` | 8 new slugify tests + 3 dotnet fixture tests |
| `tests/test_env_scanner.py` | 8 new C# / Java / Kotlin scanner tests |
| `tests/fixtures/dotnet-api/Api/Program.cs` | New C# fixture for end-to-end testing |

---

*Report generated automatically on 2026-11-05*
