import yaml
import tempfile
import pytest
from pydantic import ValidationError

from scripts.config_loader import load_config


def write_temp_yaml(content: dict):
    f = tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False)
    yaml.safe_dump(content, f)
    f.flush()
    return f.name


def test_missing_required_field_raises():
    # Remove router_mgmt_ip
    bad = {
        "watchdog": {"latency_threshold_ms": 100, "check_interval_s": 2},
        "bgp": {"flow_spec_enabled": True, "flow_spec_threshold_pps": 1000},
        "cloud_scrubbing": {"provider": "x", "api_endpoint": "https://x", "api_key": "k"},
        "automation": {"enable": True, "orchestration_interval_s": 60},
        "logging": {"level": "INFO", "file": "/tmp/log"},
    }
    path = write_temp_yaml(bad)
    with pytest.raises(ValidationError):
        load_config(path)


def test_wrong_type_field_raises():
    bad = {
        "router_mgmt_ip": "192.0.2.1",
        "watchdog": {"latency_threshold_ms": "not-an-int", "check_interval_s": 2},
        "bgp": {"flow_spec_enabled": True, "flow_spec_threshold_pps": 1000},
        "cloud_scrubbing": {"provider": "x", "api_endpoint": "https://x", "api_key": "k"},
        "automation": {"enable": True, "orchestration_interval_s": 60},
        "logging": {"level": "INFO", "file": "/tmp/log"},
    }
    path = write_temp_yaml(bad)
    with pytest.raises(ValidationError):
        load_config(path)
