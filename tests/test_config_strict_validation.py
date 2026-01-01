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


def base_good_config():
    return {
        "router_mgmt_ip": "192.0.2.1",
        "watchdog": {"latency_threshold_ms": 100, "check_interval_s": 2},
        "bgp": {"flow_spec_enabled": True, "flow_spec_threshold_pps": 1000},
        "cloud_scrubbing": {"provider": "x", "api_endpoint": "https://example.com", "api_key": "k"},
        "automation": {"enable": True, "orchestration_interval_s": 60},
        "logging": {"level": "INFO", "file": "/tmp/log"},
    }


def test_invalid_log_level_raises():
    cfg = base_good_config()
    cfg["logging"]["level"] = "INVALID"
    path = write_temp_yaml(cfg)
    with pytest.raises(ValidationError):
        load_config(path)


def test_invalid_ip_raises():
    cfg = base_good_config()
    cfg["router_mgmt_ip"] = "not-an-ip"
    path = write_temp_yaml(cfg)
    with pytest.raises(ValidationError):
        load_config(path)


def test_invalid_api_endpoint_raises():
    cfg = base_good_config()
    cfg["cloud_scrubbing"]["api_endpoint"] = "not-a-url"
    path = write_temp_yaml(cfg)
    with pytest.raises(ValidationError):
        load_config(path)
