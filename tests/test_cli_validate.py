import sys
import subprocess
import os
import tempfile
import json
import yaml


def run_cli(args):
    cmd = [sys.executable, "-m", "scripts.cli"] + args
    # Set CWD to package dir so `scripts` package can be found when invoking as a module
    cwd = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    return p


def test_cli_validate_success():
    p = run_cli(["validate"])
    assert p.returncode == 0
    assert "Config is valid" in p.stdout


def test_cli_validate_failure():
    # Write a bad config (missing required fields)
    bad = {"watchdog": {"latency_threshold_ms": 1, "check_interval_s": 1}}
    f = tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False)
    yaml.safe_dump(bad, f)
    f.flush()
    p = run_cli(["validate", "--config", f.name])
    # Expect a non-zero exit code and error message
    assert p.returncode != 0
    assert "Configuration validation failed" in p.stdout


def test_export_schema_writes_file(tmp_path):
    out = tmp_path / "schema.json"
    p = run_cli(["export-schema", "--out", str(out)])
    assert p.returncode == 0
    assert out.exists()
    data = json.loads(out.read_text())
    assert "properties" in data
