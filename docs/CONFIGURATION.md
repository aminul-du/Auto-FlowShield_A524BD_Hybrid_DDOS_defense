# Configuration — Auto-FlowShield A524BD 🔧

This document describes the configuration expected by Auto-FlowShield and includes a sample YAML configuration in `config/sample_config.yml`.

## Overview
- The project reads configuration from YAML files stored in the `config/` directory.
- Values may be overridden by environment variables (e.g., `ROUTER_MGMT_IP`) if needed — see loader notes below.

## Fields in `sample_config.yml`
- `router_mgmt_ip` — Router management IP used by safety checks and BGP operations.
- `watchdog.latency_threshold_ms` — Latency threshold (ms) that triggers the watchdog safety stop.
- `watchdog.check_interval_s` — Interval (seconds) between safety checks.
- `bgp.flow_spec_enabled` — Enable/disable BGP FlowSpec automation.
- `bgp.flow_spec_threshold_pps` — PPS threshold for FlowSpec activation.
- `cloud_scrubbing.provider` — Cloud scrubbing provider name.
- `cloud_scrubbing.api_endpoint` — API endpoint for the cloud scrubber.
- `cloud_scrubbing.api_key` — API key for accessing the provider.
- `automation.enable` — Enable/disable the automation engine.
- `automation.orchestration_interval_s` — How often orchestration runs (seconds).
- `logging.level` — Log level (DEBUG/INFO/WARN/WARNING/ERROR/CRITICAL). Only these values are accepted.
- `logging.file` — Path to the log file.
- `router_mgmt_ip` — Must be a valid IPv4 or IPv6 address.
- `cloud_scrubbing.api_endpoint` — Must be a valid HTTP/HTTPS URL.

## Loading configuration
A simple loader `scripts/config_loader.py` is included that:
1. Loads `config/sample_config.yml` (or a supplied path) using PyYAML
2. Applies environment variable overrides (e.g. `ROUTER_MGMT_IP`) when present
3. Validates the resulting configuration against a Pydantic schema (`scripts/config_schema.py`) and raises a validation error if required fields are missing or types are incorrect.

Install dependency:

```bash
pip install -r requirements.txt
```

## Next steps & recommendations
- Add secrets (API keys) to a secure store (Vault, Secrets Manager) in production instead of committing them to the repo.
- Add a `.env.example` if you prefer environment-based configuration instead of YAML.

## Continuous integration (CI)
Automated tests validate the configuration loader and sample config. A GitHub Actions workflow (`.github/workflows/ci.yml`) runs `pytest` on push and pull requests to ensure the loader continues working as expected.

The workflow also runs the CLI validator (`python -m scripts.cli validate`) to ensure the sample configuration is valid and the validator works in CI.

You can also export a JSON Schema with:

```bash
python -m scripts.cli export-schema --out config/schema.json
```

This produces a machine-readable schema that can be consumed by editors, CI checks, or external tooling.
