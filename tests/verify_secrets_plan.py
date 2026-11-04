#!/usr/bin/env python3
"""Assert Secrets Manager / SSM wiring in a terraform show -json plan output."""

from __future__ import annotations

import json
import sys
from typing import Any


def load_plan(path: str) -> dict[str, Any]:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def planned_resources(plan: dict[str, Any]) -> list[dict[str, Any]]:
    root = plan.get("planned_values", {}).get("root_module", {})
    out: list[dict[str, Any]] = []

    def walk(module: dict[str, Any]) -> None:
        out.extend(module.get("resources") or [])
        for child in module.get("child_modules") or []:
            walk(child)

    walk(root)
    return out


def resource_counts(resources: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for res in resources:
        key = res.get("type", "")
        counts[key] = counts.get(key, 0) + 1
    return counts


def secrets_by_container(plan: dict[str, Any]) -> dict[str, list[dict[str, str]]]:
    resources = planned_resources(plan)
    for res in resources:
        if res.get("type") != "aws_ecs_task_definition":
            continue
        containers = json.loads(res.get("values", {}).get("container_definitions", "[]"))
        result: dict[str, list[dict[str, str]]] = {}
        for container in containers:
            name = container.get("name")
            secrets = container.get("secrets") or []
            result[name] = [{"name": s["name"], "valueFrom": s["valueFrom"]} for s in secrets]
        return result
    raise AssertionError("aws_ecs_task_definition not found in plan")


def secret_names(entries: list[dict[str, str]]) -> set[str]:
    return {entry["name"] for entry in entries}


def value_from(entries: list[dict[str, str]], env_name: str) -> str:
    for entry in entries:
        if entry["name"] == env_name:
            return entry["valueFrom"]
    raise AssertionError(f"env {env_name} not in {entries}")


def assert_condition(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    plan_path = sys.argv[1] if len(sys.argv) > 1 else "plan.tfplan"
    plan = load_plan(plan_path)
    counts = resource_counts(planned_resources(plan))
    by_container = secrets_by_container(plan)

    assert_condition(
        counts.get("aws_secretsmanager_secret", 0) >= 10,
        f"expected many SM secrets, got {counts.get('aws_secretsmanager_secret', 0)}",
    )
    assert_condition(
        counts.get("aws_secretsmanager_secret_version", 0) >= 1,
        "expected at least one managed secret version",
    )
    assert_condition(
        counts.get("aws_secretsmanager_secret_version", 0)
        + counts.get("aws_secretsmanager_secret_version", 0)
        >= 1,
        "expected secret version resources",
    )

    unlocked = [
        resource
        for resource in planned_resources(plan)
        if resource.get("type") == "aws_secretsmanager_secret_version"
        and "container_env_unlocked_value" in resource.get("address", "")
    ]
    assert_condition(len(unlocked) >= 1, "expected per-key unlocked secret version resource")

    json_unlocked = [
        resource
        for resource in planned_resources(plan)
        if resource.get("type") == "aws_secretsmanager_secret_version"
        and "container_json_unlocked_value" in resource.get("address", "")
    ]
    assert_condition(len(json_unlocked) >= 1, "expected JSON unlocked secret version resource")

    # Per-key create
    create = by_container["per-key-create"]
    assert_condition("DEBUG" in secret_names(create), "per-key-create missing DEBUG")
    assert_condition("secretsmanager" in value_from(create, "DEBUG"), "DEBUG should use Secrets Manager")

    # Per-key unlock
    unlock = by_container["per-key-unlock"]
    assert_condition("LOCKED" in secret_names(unlock), "per-key-unlock missing LOCKED")

    # Per-key file + inline override
    file_container = by_container["per-key-file"]
    assert_condition({"FILE_VAR", "INLINE"} <= secret_names(file_container), "per-key-file secrets")

    # Per-key JSON key ref
    ref_json = by_container["per-key-ref-json"]
    vf = value_from(ref_json, "DATABASE_URL")
    assert_condition(vf.endswith(":DATABASE_URL::"), f"expected JSON key suffix, got {vf}")

    # Whole secret ref (no suffix)
    ref_whole = by_container["per-key-ref-whole"]
    vf_whole = value_from(ref_whole, "API_KEY")
    assert_condition(":API_KEY::" not in vf_whole, f"whole secret ref should not use key suffix: {vf_whole}")

    # Ref by name (mocked ARN in plan)
    ref_name = by_container["per-key-ref-name"]
    assert_condition("MANUAL" in secret_names(ref_name), "per-key-ref-name missing MANUAL")

    # JSON create — same ARN, different keys
    json_create = by_container["json-create"]
    assert_condition({"APP_MODE", "FEATURE"} <= secret_names(json_create), "json-create keys")
    app_mode_vf = value_from(json_create, "APP_MODE")
    feature_vf = value_from(json_create, "FEATURE")
    assert_condition(
        app_mode_vf.rsplit(":", 2)[0] == feature_vf.rsplit(":", 2)[0],
        "json-create secrets should share one secret ARN",
    )
    assert_condition(app_mode_vf.endswith(":APP_MODE::"), "APP_MODE json key suffix")

    # JSON unlock + manual key
    json_unlock = by_container["json-unlock"]
    assert_condition({"BOOTSTRAP", "MANUAL_JSON_KEY"} <= secret_names(json_unlock), "json-unlock keys")

    # JSON from file
    json_file = by_container["json-file"]
    assert_condition(
        {"JSON_FILE_KEY", "LOG_LEVEL"} <= secret_names(json_file),
        "json-file keys from env file",
    )

    # JSON ref by ARN
    json_ref_arn = by_container["json-ref-arn"]
    assert_condition({"REF_A", "REF_B"} <= secret_names(json_ref_arn), "json-ref-arn keys")
    ref_a = value_from(json_ref_arn, "REF_A")
    assert_condition(
        ref_a.startswith("arn:aws:secretsmanager:") and ref_a.endswith(":REF_A::"),
        ref_a,
    )

    # JSON ref by name + map alias
    json_ref_name = by_container["json-ref-name"]
    assert_condition("ALIAS_ENV" in secret_names(json_ref_name), "json-ref-name alias env")
    assert_condition(
        value_from(json_ref_name, "ALIAS_ENV").endswith(":actual_json_key::"),
        "json map should rename JSON key",
    )

    # SSM + SM merge
    combined = by_container["ssm-plus-sm"]
    assert_condition({"FROM_SSM", "FROM_SM"} <= secret_names(combined), "ssm-plus-sm merge")

    # Raw secrets passthrough
    raw = by_container["raw-passthrough"]
    assert_condition({"TF_SM", "RAW"} <= secret_names(raw), "raw passthrough")
    assert_condition(
        value_from(raw, "RAW").startswith("arn:aws:ssm:"),
        "RAW should stay SSM arn",
    )

    iam_policies = [
        resource
        for resource in planned_resources(plan)
        if resource.get("type") == "aws_iam_policy" and "EcsTaskExecPolicy" in resource.get("address", "")
    ]
    assert_condition(iam_policies, "task execution IAM policy missing from plan")
    policy_doc = json.loads(iam_policies[0]["values"]["policy"])
    actions = {
        action
        for statement in policy_doc.get("Statement", [])
        for action in (
            statement.get("Action") if isinstance(statement.get("Action"), list) else [statement.get("Action")]
        )
    }
    assert_condition("secretsmanager:GetSecretValue" in actions, "missing GetSecretValue on task exec role")
    assert_condition("ssm:GetParameters" in actions, "missing GetParameters when SSM is used")

    print("All secrets pattern plan checks passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
