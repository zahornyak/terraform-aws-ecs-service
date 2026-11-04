#!/usr/bin/env python3
"""Validate merged ECS container secrets from module.ecs.container_definitions JSON."""

from __future__ import annotations

import json
import sys
from typing import Any


def load_containers(path: str) -> dict[str, dict[str, Any]]:
    with open(path, encoding="utf-8") as handle:
        payload = json.load(handle)
    if isinstance(payload, str):
        containers = json.loads(payload)
    else:
        containers = payload
    return {container["name"]: container for container in containers}


def secret_map(container: dict[str, Any]) -> dict[str, str]:
    return {entry["name"]: entry["valueFrom"] for entry in (container.get("secrets") or [])}


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "container_definitions.json"
    by_name = load_containers(path)

    checks = {
        "per-key-create": {"DEBUG"},
        "per-key-unlock": {"LOCKED"},
        "per-key-file": {"FILE_VAR", "INLINE"},
        "per-key-ref-json": {"DATABASE_URL"},
        "per-key-ref-whole": {"API_KEY"},
        "per-key-ref-name": {"MANUAL"},
        "json-create": {"APP_MODE", "FEATURE"},
        "json-unlock": {"BOOTSTRAP", "MANUAL_JSON_KEY"},
        "json-file": {"JSON_FILE_KEY", "LOG_LEVEL"},
        "json-ref-arn": {"REF_A", "REF_B"},
        "json-ref-name": {"FROM_NAME", "ALIAS_ENV"},
        "ssm-plus-sm": {"FROM_SSM", "FROM_SM"},
        "raw-passthrough": {"TF_SM", "RAW"},
    }

    for container_name, expected in checks.items():
        if container_name not in by_name:
            raise AssertionError(f"missing container {container_name}")
        names = set(secret_map(by_name[container_name]))
        if expected - names:
            raise AssertionError(f"{container_name}: expected {expected}, got {names}")

    db = secret_map(by_name["per-key-ref-json"])["DATABASE_URL"]
    if not db.endswith(":DATABASE_URL::"):
        raise AssertionError(f"per-key-ref-json suffix wrong: {db}")

    whole = secret_map(by_name["per-key-ref-whole"])["API_KEY"]
    if ":API_KEY::" in whole:
        raise AssertionError(f"whole secret ref should not use key suffix: {whole}")

    json_create = secret_map(by_name["json-create"])
    app = json_create["APP_MODE"]
    feat = json_create["FEATURE"]
    if app.rsplit(":", 2)[0] != feat.rsplit(":", 2)[0]:
        raise AssertionError("json-create secrets should share ARN prefix")
    if not app.endswith(":APP_MODE::"):
        raise AssertionError(app)

    alias = secret_map(by_name["json-ref-name"])["ALIAS_ENV"]
    if not alias.endswith(":actual_json_key::"):
        raise AssertionError(alias)

    raw = secret_map(by_name["raw-passthrough"])["RAW"]
    if not raw.startswith("arn:aws:ssm:"):
        raise AssertionError(raw)

    print("All container_definitions secret pattern checks passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
