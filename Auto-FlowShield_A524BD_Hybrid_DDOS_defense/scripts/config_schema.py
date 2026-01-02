"""Pydantic models for configuration validation"""
from typing import Literal
import ipaddress

from pydantic import BaseModel, Field, field_validator, HttpUrl


class Watchdog(BaseModel):
    latency_threshold_ms: int = Field(..., ge=0)
    check_interval_s: int = Field(..., ge=0)


class BGP(BaseModel):
    flow_spec_enabled: bool = Field(default=True)
    flow_spec_threshold_pps: int = Field(..., ge=0)


class CloudScrubbing(BaseModel):
    provider: str
    api_endpoint: HttpUrl
    api_key: str


class Automation(BaseModel):
    enable: bool
    orchestration_interval_s: int = Field(..., ge=0)


class Logging(BaseModel):
    level: Literal["DEBUG", "INFO", "WARN", "WARNING", "ERROR", "CRITICAL"]
    file: str


class ConfigModel(BaseModel):
    router_mgmt_ip: str
    watchdog: Watchdog
    bgp: BGP
    cloud_scrubbing: CloudScrubbing
    automation: Automation
    logging: Logging

    @field_validator("router_mgmt_ip")
    @classmethod
    def validate_ip(cls, v):
        try:
            ipaddress.ip_address(v)
        except Exception as e:
            raise ValueError("router_mgmt_ip must be a valid IP address") from e
        return v
