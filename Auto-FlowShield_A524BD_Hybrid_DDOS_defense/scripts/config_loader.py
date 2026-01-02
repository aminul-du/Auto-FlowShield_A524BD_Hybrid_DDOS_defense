"""Simple YAML config loader for Auto-FlowShield"""
import os

try:
    import yaml
except Exception as e:
    raise SystemExit("PyYAML is required. Install with: pip install pyyaml")


def load_config(path=None):
    # Default path is relative to the package location so imports/tests work
    base = os.path.dirname(os.path.dirname(__file__))
    default_path = os.path.join(base, "config", "sample_config.yml")
    path = path or default_path

    with open(path, "r") as f:
        cfg = yaml.safe_load(f) or {}

    # Apply common environment overrides
    if os.getenv("ROUTER_MGMT_IP"):
        cfg["router_mgmt_ip"] = os.getenv("ROUTER_MGMT_IP")

    # Example: allow switching provider api key by env var
    if os.getenv("CLOUD_SCRUBBING_API_KEY"):
        cfg.setdefault("cloud_scrubbing", {})["api_key"] = os.getenv("CLOUD_SCRUBBING_API_KEY")

    # Validate config against schema
    try:
        from scripts.config_schema import ConfigModel
        validated = ConfigModel(**cfg)
        # Use Pydantic v2 `model_dump()` to avoid deprecation warnings from `dict()`
        return validated.model_dump()
    except Exception as e:
        # Surface pydantic validation errors clearly
        raise


if __name__ == "__main__":
    print(load_config())
