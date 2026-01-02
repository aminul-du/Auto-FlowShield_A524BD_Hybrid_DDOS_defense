import os
import pytest

from scripts.config_loader import load_config


def test_load_sample_config():
    cfg = load_config()
    assert isinstance(cfg, dict)
    # Basic expected keys
    assert "router_mgmt_ip" in cfg
    assert "watchdog" in cfg
    assert cfg.get("watchdog", {}).get("latency_threshold_ms") == 100


def test_env_overrides(monkeypatch):
    monkeypatch.setenv("ROUTER_MGMT_IP", "198.51.100.5")
    monkeypatch.setenv("CLOUD_SCRUBBING_API_KEY", "envkey123")

    cfg = load_config()
    assert cfg["router_mgmt_ip"] == "198.51.100.5"
    assert cfg["cloud_scrubbing"]["api_key"] == "envkey123"


def test_missing_file_raises():
    with pytest.raises(FileNotFoundError):
        load_config("nonexistent_config.yml")
