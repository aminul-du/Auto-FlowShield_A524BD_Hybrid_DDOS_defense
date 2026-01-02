"""CLI for configuration tasks: validate and export json-schema"""
import argparse
import json
import sys
from pydantic import ValidationError

from scripts.config_loader import load_config
from scripts.config_schema import ConfigModel


def cmd_validate(args):
    try:
        cfg = load_config(args.config)
        print("Config is valid ✅")
        return 0
    except FileNotFoundError as e:
        print(f"Config file not found: {e}")
        return 2
    except ValidationError as e:
        # User-friendly error output
        print("Configuration validation failed:\n")
        print(e)
        return 3
    except Exception as e:
        print(f"Unexpected error: {e}")
        return 4


def cmd_export_schema(args):
    schema = ConfigModel.model_json_schema()
    out = args.out or "config/schema.json"
    with open(out, "w") as f:
        json.dump(schema, f, indent=2)
    print(f"Schema exported to {out}")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="flowshield-cli")
    sub = parser.add_subparsers(dest="command")

    p_val = sub.add_parser("validate", help="Validate a config file")
    p_val.add_argument("--config", help="Path to config YAML (defaults to sample config)")

    p_exp = sub.add_parser("export-schema", help="Export JSON Schema for config")
    p_exp.add_argument("--out", help="Output path for schema (defaults to config/schema.json)")

    args = parser.parse_args(argv)
    if args.command == "validate":
        return cmd_validate(args)
    if args.command == "export-schema":
        return cmd_export_schema(args)

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
